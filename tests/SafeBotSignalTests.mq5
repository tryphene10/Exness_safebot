#property strict
// Exercise the actual production signal and input functions, with closed-bar fixtures.
#define OnInit SB_TestUnusedInit
#define OnDeinit SB_TestUnusedDeinit
#define OnTick SB_TestUnusedTick
#define OnTimer SB_TestUnusedTimer
#define OnTradeTransaction SB_TestUnusedTransaction
#define OnTester SB_TestUnusedTester
#include "../ExnessSafeBot.mq5"
int Passed=0,Failed=0;
void Check(bool ok,string name)
{
   if(ok) Passed++; else Failed++;
   Print("SB3_SIGNAL_TEST | ",ok ? "PASS | " : "FAIL | ",name);
}
void Fixture(Snapshot &d)
{
   ArrayResize(States,1); ZeroMemory(States[0]);
   ArrayResize(d.bars,40); ArrayResize(d.fast,3); ArrayResize(d.slow,3);
   ArrayResize(d.rsi,3); ArrayResize(d.atr,40);
   for(int k=0;k<40;k++)
   {
      d.bars[k].time=D'2026.09.09 12:00:00'-k*3600;
      d.bars[k].open=100; d.bars[k].close=100; d.bars[k].low=99; d.bars[k].high=101; d.atr[k]=1;
   }
   d.fast[0]=100.2; d.fast[1]=100; d.slow[0]=99.8; d.slow[1]=99.8;
   d.rsi[0]=53; d.rsi[1]=51; d.direction=1; d.regime=REG_TREND;
   d.rangeValid=false; d.structurePattern=0; d.breakoutVolumeRatio=1.20; d.springVolumeRatio=1.20;
   d.bars[0].close=100.5;
}
void OnStart()
{
   Tester=true;
   ArrayResize(States,1); ZeroMemory(States[0]); States[0].symbol="EURUSD";
   AuditHandle=FileOpen("SB3-audit-fixture.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,';',CP_UTF8);
   Check(AuditHandle!=INVALID_HANDLE,"audit file opens");
   Audit(0,"EXECUTION_AUDIT",9007199254740993,0.01,1.10,0.50,0.02,"fixture");
   FileClose(AuditHandle); AuditHandle=INVALID_HANDLE;
   int auditRead=FileOpen("SB3-audit-fixture.csv",FILE_READ|FILE_CSV|FILE_ANSI,';',CP_UTF8);
   Check(auditRead!=INVALID_HANDLE,"audit file readable");
   if(auditRead!=INVALID_HANDLE)
   {
      FileReadString(auditRead);
      Check(FileReadString(auditRead)=="EXECUTION_AUDIT","audit event preserved");
      Check(FileReadString(auditRead)=="EURUSD","audit symbol preserved");
      Check(FileReadString(auditRead)=="9007199254740993","audit ID preserves 64 bit precision");
      FileClose(auditRead);
   }
   Check(ValidateInputs(),"default parameters valid");
   Check(ReadState(0,"missing-state",42)==42,"tester preserves runtime fallback state");
   Snapshot d; string engine;
   Fixture(d); Check(Signal(0,d,engine)==0,"trend engine disabled by conservative default");
   Fixture(d); d.rsi[1]=54; Check(Signal(0,d,engine)==0,"no repeated RSI-above entry");
   Fixture(d); d.direction=0; Check(Signal(0,d,engine)==0,"neutral H4 blocks entry");
   Fixture(d); d.regime=REG_EXCESS_VOL; Check(Signal(0,d,engine)==0,"excess volatility blocks entry");
   Fixture(d); d.regime=REG_RANGE; Check(Signal(0,d,engine)==0,"no mean reversion engine");
   Fixture(d); d.bars[1].low=105; d.bars[1].high=106; Check(Signal(0,d,engine)==0,"pullback must touch EMA zone");
   Fixture(d); d.direction=-1; d.fast[0]=99.8; d.slow[0]=100.2;
   d.rsi[1]=49; d.rsi[0]=47; d.bars[0].close=99.5;
   Check(Signal(0,d,engine)==0,"bearish trend entry disabled by conservative default");
   Fixture(d); d.regime=REG_BREAKOUT; d.atr[0]=1.1; d.bars[0].close=102;
   Check(Signal(0,d,engine)==1 && engine=="BREAKOUT","compressed box breakout");
   Check(States[0].boxHigh==101,"breakout level excludes signal candle");
   Fixture(d); d.regime=REG_BREAKOUT; d.bars[0].close=102;
   Check(Signal(0,d,engine)==0,"breakout requires ATR expansion");
   Fixture(d); d.regime=REG_BREAKOUT; d.atr[0]=1.1; d.bars[0].close=102; d.direction=-1;
   Check(Signal(0,d,engine)==0,"breakout must agree with H4");
   Fixture(d); d.regime=REG_BREAKOUT; d.atr[0]=1.1; d.bars[0].close=102; d.breakoutVolumeRatio=1.0;
   Check(Signal(0,d,engine)==0,"breakout rejected below relative-volume threshold");
   Fixture(d); d.regime=REG_BREAKOUT; d.atr[0]=1.1; d.bars[0].close=102; d.breakoutVolumeRatio=4.1;
   Check(Signal(0,d,engine)==0,"breakout rejected during volume climax");
   Fixture(d); d.regime=REG_RANGE; d.rangeValid=true; d.structurePattern=1; d.direction=0;
   Check(Signal(0,d,engine)==1 && engine=="SPRING","confirmed Spring buy signal");
   Fixture(d); d.regime=REG_RANGE; d.rangeValid=true; d.structurePattern=-1; d.direction=0;
   Check(Signal(0,d,engine)==-1 && engine=="UPTHRUST","confirmed Upthrust sell signal");
   Fixture(d); d.regime=REG_RANGE; d.rangeValid=true; d.structurePattern=1; d.direction=-1;
   Check(Signal(0,d,engine)==0,"Spring blocked against H4 direction");
   Fixture(d); d.regime=REG_RANGE; d.rangeValid=true; d.structurePattern=-2; d.direction=-1;
   Check(Signal(0,d,engine)==0,"failed Spring detection is observation-only by default");
   Fixture(d); d.regime=REG_RANGE; d.rangeValid=true; d.structurePattern=1; d.direction=0; d.springVolumeRatio=4.1;
   Check(Signal(0,d,engine)==0,"Spring rejected during volume climax");
   Fixture(d); d.regime=REG_BREAKOUT; d.atr[0]=1.1; d.bars[0].close=102;
   States[0].usedCompression=d.bars[0].time+InpCompressionBars*3600;
   Check(Signal(0,d,engine)==0,"consumed compression cannot rearm immediately");
   int file=FileOpen("SB3-signal-test-results.txt",FILE_WRITE|FILE_TXT);
   if(file!=INVALID_HANDLE) { FileWrite(file,StringFormat("PASS=%d FAIL=%d",Passed,Failed)); FileClose(file); }
   PrintFormat("SB3_SIGNAL_TEST_RESULT | PASS=%d FAIL=%d",Passed,Failed);
}
