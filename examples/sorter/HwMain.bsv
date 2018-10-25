import FIFO::*;
import FIFOF::*;
import Clocks::*;
import Vector::*;

import BRAM::*;
import BRAMFIFO::*;

import PcieCtrl::*;
import MergeN::*;
import MergeSorter::*;

import DMAReadHelper::*;
import DMAWriteHelper::*;
import ShiftPacker::*;

interface HwMainIfc;
endinterface

function Tuple2#(Bit#(ksz),Bit#(vsz)) decodeTuple2(Bit#(w) in)
	provisos(Add#(ksz,vsz,w)
	);

	Bit#(ksz) keybits = truncate(in);
	Bit#(vsz) valbits = truncate(in>>valueOf(ksz));

	return tuple2(keybits, valbits);
endfunction

function Bit#(w) encodeTuple2(Tuple2#(Bit#(ksz),Bit#(vsz)) kvp)
	provisos(Add#(ksz,vsz,w)
	);
	Bit#(ksz) keybits = tpl_1(kvp);
	Bit#(vsz) valbits = tpl_2(kvp);

	return {valbits,keybits};
endfunction

function Bit#(vsz) reducerFunction(Bit#(vsz) v1, Bit#(vsz) v2);
	return v1+v2;
endfunction

/*****
Note: during reset
inject invalid to all vRelay that did not already have invalid
throw away all output  from sorter

throw away all output from dmareader
throw away all done signals from reader,writer
*****/


module mkHwMain#(PcieUserIfc pcie) 
	(HwMainIfc);

	Clock curclk <- exposeCurrentClock;
	Reset currst <- exposeCurrentReset;

	Clock pcieclk = pcie.user_clk;
	Reset pcierst = pcie.user_rst;

	Integer iFanIn = 32;
	
	Reg#(Bit#(32)) cycleCounter <- mkReg(0);
	rule incCyle;
		cycleCounter <= cycleCounter + 1;
	endrule
	SyncFIFOIfc#(Bool) resetReqQ <- mkSyncFIFO(16, pcieclk, pcierst, curclk);
	Reg#(Bit#(8)) resetCounter <- mkReg(0);
	rule incResetCnt;
		resetReqQ.deq;
		resetCounter <= resetCounter + 1;
	endrule

	SyncFIFOIfc#(Bit#(16)) dmarDoneQ <- mkSyncFIFO(32, curclk, currst, pcieclk);
	SyncFIFOIfc#(Tuple2#(Bit#(64),Bit#(32))) sampleKvQ <- mkSyncFIFO(32, curclk, currst, pcieclk);
	
	DMAReadHelperIfc dmar <- mkDMAReadHelper(pcie);
	DMAWriteHelperIfc dmaw <- mkDMAWriteHelper(pcie);
	FIFO#(Tuple2#(Bool, Bit#(16))) dmarTargetIdxQ <- mkSizedFIFO(16);
	
	StreamMergeSorterIfc#(32, Bit#(64), Bit#(32)) sorter <- mkMergeSorterSingle32(False);
	Vector#(32, ShiftUnpackerIfc#(Bit#(128), Bit#(96))) unpackers <- replicateM(mkShiftUnpacker);

	ShiftPackerIfc#(Bit#(128), Bit#(96)) packer <- mkShiftPacker;
	//Vector#(32, FIFO#(Maybe#(Bit#(128)))) vRelayQ <- replicateM(mkSizedBRAMFIFO(512)); // 8 KB
	ScatterNIfc#(32,Maybe#(Bit#(128))) relayS <- mkScatterN;
	//Vector#(32, FIFO#(Bit#(32))) vReadCntQ <- replicateM(mkSizedFIFO(16)); // 8 KB
	ScatterNIfc#(32, Bit#(32)) readCntS <- mkScatterN;
	MergeNIfc#(32, Bit#(16)) dmarDoneM <- mkMergeN;
	for ( Integer i = 0; i < iFanIn; i=i+1 ) begin
		FIFO#(Maybe#(Bit#(128))) relayQ <- mkSizedBRAMFIFO(512); // 8 KB
		Reg#(Bit#(32)) curReadWordsCnt <- mkReg(0);
		rule relayVRelay;
			relayS.get[i].deq;
			relayQ.enq(relayS.get[i].first);
		endrule
		rule relayRelayQ;
			relayQ.deq;
			let d = relayQ.first;

			unpackers[i].put(d);

			if ( isValid(d) ) begin
				if ( curReadWordsCnt + 1 >= readCntS.get[i].first ) begin
					dmarDoneM.enq[i].enq(fromInteger(i));
					curReadWordsCnt <= 0;
					readCntS.get[i].deq;
				end else begin
					curReadWordsCnt <= curReadWordsCnt + 1;
				end
			end
		endrule
		rule insertSorter;
			let d <- unpackers[i].get;

			if ( isValid(d) ) begin
				let dd = decodeTuple2(fromMaybe(?,d));
				sorter.enq[i].enq(tagged Valid dd);
			end else begin
				sorter.enq[i].enq(tagged Invalid);
			end
		endrule
	end
	rule relayDmarDoneM;
		dmarDoneM.deq;
		dmarDoneQ.enq(dmarDoneM.first);
	endrule

	Reg#(Bit#(32)) dmarTargetRelayWordsLeft <- mkReg(0);
	Reg#(Bit#(16)) dmarCurTarget <- mkReg(0);
	Reg#(Bool) dmarFlush <- mkReg(False);
	rule procDmaTargetIdx ( dmarTargetRelayWordsLeft == 0 );
		dmarTargetIdxQ.deq;
		let d = dmarTargetIdxQ.first;
		if ( tpl_1(d) ) begin
			dmarCurTarget <= (tpl_2(d));
			dmarTargetRelayWordsLeft <= (1<<8);// 4 KB worth 16 byte words
		end else begin
			dmarCurTarget <= (tpl_2(d));
			dmarTargetRelayWordsLeft <= 1;// Just one
			dmarFlush <= True;
		end
	endrule
	Reg#(Bit#(8)) relayDmaResetCnt <- mkReg(0);
	rule relayDmaTarget ( relayDmaResetCnt==resetCounter && dmarTargetRelayWordsLeft > 0 );
		if ( dmarFlush ) begin
			relayS.enq(tagged Invalid, truncate(dmarCurTarget));
			dmarFlush <= False;
			dmarTargetRelayWordsLeft <= 0;
		end else begin
			let r <- dmar.read;
			relayS.enq(tagged Valid r, truncate(dmarCurTarget));
			dmarTargetRelayWordsLeft <= dmarTargetRelayWordsLeft - 1;
		end
	endrule

	Reg#(Bit#(32)) relayDmaResetCycleTarget <- mkReg(0);
	Reg#(Bit#(8)) relayInvalidIdx <- mkReg(0);
	rule resetRelayDma (relayDmaResetCnt!=resetCounter);
		// if reset, insert invalid once to all, and throw away values for a few thousand cycles
		if ( relayDmaResetCycleTarget == 0 ) begin
			relayDmaResetCycleTarget <= cycleCounter + (1024*1024*4);
			relayInvalidIdx <= fromInteger(iFanIn);
		end else if ( relayDmaResetCycleTarget - cycleCounter < 256 )  begin // 256 so we don't miss the ending
			relayDmaResetCnt <= relayDmaResetCnt + 1;
			relayDmaResetCycleTarget <= 0;
		end else begin
			let r <- dmar.read;
			if ( relayInvalidIdx > 0 ) begin
				relayS.enq(tagged Invalid, relayInvalidIdx -1);
				relayInvalidIdx <= relayInvalidIdx - 1;
			end
		end

	endrule

	Reg#(Maybe#(Tuple2#(Bit#(64),Bit#(32)))) lastKvp <- mkReg(tagged Invalid);
	FIFO#(Maybe#(Tuple2#(Bit#(64),Bit#(32)))) sortReducedQ <- mkFIFO;

	Reg#(Bit#(8)) sorterResultsResetCnt <- mkReg(0);
	Reg#(Bool) sortResultFlushing <- mkReg(False);
	rule getSortResult (sorterResultsResetCnt==resetCounter && !sortResultFlushing);
		let s <- sorter.get;
		let ss = fromMaybe(?,s);
		let lp = fromMaybe(?,lastKvp);

		if ( isValid(s) ) begin
			if ( isValid(lastKvp) ) begin
				if ( tpl_1(ss) == tpl_1(lp) ) begin
					lastKvp <= tagged Valid tuple2(tpl_1(ss), reducerFunction(tpl_2(ss),tpl_2(lp)));
				end else begin
					sortReducedQ.enq(lastKvp);
					lastKvp <= s;
				end
			end else begin
				lastKvp <= s;
			end
		end else begin
			if ( isValid(lastKvp) ) begin
				sortReducedQ.enq(lastKvp);
				sortResultFlushing <= True;
			end else begin
				sortReducedQ.enq(tagged Invalid);
			end
			lastKvp <= tagged Invalid;
		end
	endrule
	rule flushSortResult (sorterResultsResetCnt==resetCounter && sortResultFlushing);
		sortResultFlushing <= False;
		sortReducedQ.enq(tagged Invalid);
	endrule

	rule resetSortResult (sorterResultsResetCnt!=resetCounter);
		let s <- sorter.get;
		if ( !isValid(s) ) begin
			sorterResultsResetCnt <= sorterResultsResetCnt + 1;
		end
	endrule
    
	rule packReduced;
		sortReducedQ.deq;
		let d = sortReducedQ.first;

		if ( isValid(d) ) begin
			let dd = fromMaybe(?,d);
			let key = tpl_1(dd);
			let val = tpl_2(dd);
			if ( sampleKvQ.notFull ) begin
				sampleKvQ.enq(dd);
			end

			packer.put(tagged Valid encodeTuple2(dd));
		end else begin
			packer.put(tagged Invalid);
		end
		// when reset, throw away until invalid reached
	endrule

	Reg#(Bit#(8)) dmaWritePResetCnt <- mkReg(0);
	rule sendHost ( dmaWritePResetCnt==resetCounter );
		let d <- packer.get;
		dmaw.write(d);
	endrule
	rule resetSendHost ( dmaWritePResetCnt!=resetCounter );
		dmaWritePResetCnt <= dmaWritePResetCnt + 1;
		dmaw.write(tagged Invalid);
	endrule
	
	SyncFIFOIfc#(Tuple2#(Bit#(16), Bit#(16))) dmaReadReqQ <- mkSyncFIFO(16, pcieclk, pcierst, curclk);
	rule startDmaRead;
		dmaReadReqQ.deq;
		let r = dmaReadReqQ.first;
		Bit#(32) oid = zeroExtend(tpl_1(r));
		Bit#(32) offset = (oid<<12); // 4 KB
		Bit#(16) target = tpl_2(r);
		if ( oid >= 1024 ) begin
			dmarTargetIdxQ.enq(tuple2(False,target));
		end else begin
			dmar.readReq(offset, (1<<12));
			dmarTargetIdxQ.enq(tuple2(True,target));
			readCntS.enq((1<<8), truncate(target));
		end
	endrule
	SyncFIFOIfc#(Bit#(32)) dmaWriteBufferQ <- mkSyncFIFO(16, pcieclk, pcierst, curclk);
	SyncFIFOIfc#(Tuple3#(Bool, Bit#(32),Bit#(32))) dmaWriteBufferDoneQ <- mkSyncFIFO(16,curclk,currst,pcieclk);
	rule insertDmaWriteBuffer;
		dmaWriteBufferQ.deq;
		let d = dmaWriteBufferQ.first;
		dmaw.addHostBuffer((d<<12), (1<<12));
	endrule


	rule relayDmaWriteDone; 
		let d <- dmaw.bufferDone;
		dmaWriteBufferDoneQ.enq(d);
	endrule
	
	Reg#(Bit#(8)) resetCounterC <- mkReg(0, clocked_by pcieclk, reset_by pcierst);
	Reg#(Bit#(32)) cycleCounterC <- mkReg(0, clocked_by pcieclk, reset_by pcierst);
	rule incCycleC;
		cycleCounterC <= cycleCounterC + 1;
	endrule

	Reg#(Bit#(8)) dmaDoneResetCounter <- mkReg(0, clocked_by pcieclk, reset_by pcierst);
	Reg#(Bit#(32)) dmaDoneResetCycleTarget <- mkReg(0, clocked_by pcieclk, reset_by pcierst);
	rule resetDmaWriteDone ( dmaDoneResetCounter!=resetCounterC);
		if ( dmaDoneResetCycleTarget == 0 ) begin
			dmaDoneResetCycleTarget <= cycleCounterC + (1024*1024*4);
		end else if ( dmaDoneResetCycleTarget - cycleCounterC < 256 )  begin // 256 so we don't miss the ending
			dmaDoneResetCounter <= dmaDoneResetCounter + 1;
			dmaDoneResetCycleTarget <= 0;
		end else begin
		end
		if ( dmaWriteBufferDoneQ.notEmpty ) dmaWriteBufferDoneQ.deq;
		if ( dmarDoneQ.notEmpty ) dmarDoneQ.deq;
	endrule


	rule getCmd; // ( memReadLeft == 0 && memWriteLeft == 0 );
		let w <- pcie.dataReceive;
		let a = w.addr;
		let d = w.data;
		let off = (a>>2);

		if ( off == 0 ) begin
			// Read source
			Bit#(16) target = d[31:16];
			Bit#(16) buffer = d[15:0];
			dmaReadReqQ.enq(tuple2(buffer, target));
		end else if ( off == 1 ) begin
			dmaWriteBufferQ.enq(d);
		end else if ( off == 2 ) begin
			//reset
			resetReqQ.enq(True);
			resetCounterC <= resetCounterC + 1;
		end
	endrule

	rule readStat;
		let r <- pcie.dataReq;
		let a = r.addr;

		// PCIe IO is done at 4 byte granularities
		// lower 2 bits are always zero
		let offset = (a>>2);

		if ( offset == 0 ) begin
			if ( dmarDoneQ.notEmpty && dmaDoneResetCounter == resetCounterC ) begin
				dmarDoneQ.deq;
				pcie.dataSend(r, zeroExtend(dmarDoneQ.first));
			end else begin
				pcie.dataSend(r, 32'hffffffff);
			end
		end else if ( offset == 1 ) begin
			if ( dmaWriteBufferDoneQ.notEmpty && dmaDoneResetCounter == resetCounterC ) begin
				dmaWriteBufferDoneQ.deq;
				let d = dmaWriteBufferDoneQ.first;
				let off = tpl_2(d);
				let bytes = tpl_3(d);
				let idx = (off>>12);
				Bit#(1) last = tpl_1(d)?1:0;
				pcie.dataSend(r, {last, idx[14:0],bytes[15:0]});
			end else begin
				pcie.dataSend(r, 32'hffffffff);
			end
		end else if ( offset == 32 ) begin
			if ( sampleKvQ.notEmpty ) begin
				pcie.dataSend(r, truncateLSB(tpl_1(sampleKvQ.first)));
			end else begin
				pcie.dataSend(r, 32'hffffffff);
			end
		end else if ( offset == 33 ) begin
			if ( sampleKvQ.notEmpty ) begin
				pcie.dataSend(r, truncate(tpl_1(sampleKvQ.first)));
			end else begin
				pcie.dataSend(r, 32'hffffffff);
			end
		end else if ( offset == 34 ) begin
			if ( sampleKvQ.notEmpty ) begin
				sampleKvQ.deq;
				pcie.dataSend(r, tpl_2(sampleKvQ.first));
			end else begin
				pcie.dataSend(r, 32'hffffffff);
			end
		end else begin
			pcie.dataSend(r, 32'hffffffff);
		end
	endrule
endmodule
