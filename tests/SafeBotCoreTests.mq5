#property strict
#property script_show_inputs
#include "../Include/SafeBotCore.mqh"
int Passed=0,Failed=0;
void Check(bool ok,string name)
{
   if(ok) Passed++; else Failed++;
   Print("SB3_TEST | ",ok ? "PASS | " : "FAIL | ",name);
}
void OnStart()
{
   Check(SB_CashAnchor(1000,1500,1000)==1500,"deposit adjusts peak denominator");
   Check(SB_CashAnchor(1000,600,1000)==600,"withdrawal adjusts daily denominator");
   Check(SB_CashAnchor(1000,1500,1000)-1490==10,"deposit preserves loss amount");
   Check(SB_CashAnchor(1000,600,1000)-590==10,"withdrawal preserves loss amount");
   Check(SB_MarginAllows(1000,0,300),"zero margin allowed");
   Check(SB_MarginAllows(900,300,300),"margin exact boundary");
   Check(!SB_MarginAllows(899,300,300),"margin below floor refused");
   Check(!SB_MarginAllows(1000,800,300),"80 percent margin consumption refused");
   Check(!SB_MarginAllows(0,0,300),"zero equity refused");
   Check(SB_ExecutionSafe(99,102,5,5,0.05,0.05),"execution at budget accepted");
   Check(SB_ExecutionSafe(99,102,2,5,0.02,0.05),"partial fill below budget accepted");
   Check(!SB_ExecutionSafe(0,102,0,5,0.05,0.05),"missing SL rejected");
   Check(!SB_ExecutionSafe(99,0,5,5,0.05,0.05),"missing TP rejected");
   Check(!SB_ExecutionSafe(99,102,5.01,5,0.05,0.05),"slippage over budget rejected");
   Check(!SB_ExecutionSafe(99,102,5,5,0.06,0.05),"excess fill volume rejected");
   Check(SB_Volume(17*0.005,100,0.01,100,0.01)==0,"17 USD rejects minimum lot");
   Check(MathAbs(SB_Volume(5,100,0.01,100,0.01)-0.05)<1e-9,"1000 USD budget");
   Check(MathAbs(SB_Volume(5.9,100,0.01,100,0.01)-0.05)<1e-9,"volume rounds DOWN");
   Check(SB_Volume(5,0,0.01,100,0.01)==0,"invalid risk refused");
   Check(SB_Volume(5,100,0.01,100,0)==0,"invalid step refused");
   Check(MathAbs(SB_Volume(100,100,0.25,10,0.25)-1)<1e-9,"nondecimal lot step");
   Check(SB_Volume(1000,100,0.01,0.5,0.01)<=0.5,"maximum volume respected");
   Check(MathAbs(SB_RiskBudget(1000,0.5,1.0,5.0)-5.0)<1e-9,"cash risk reaches 5 at 1000 equity");
   Check(MathAbs(SB_RiskBudget(2000,0.5,1.0,5.0)-5.0)<1e-9,"cash risk cap is absolute");
   Check(MathAbs(SB_RiskBudget(1000,0.5,0.5,5.0)-2.5)<1e-9,"drawdown reduces cash risk cap");
   Check(MathAbs(SB_RiskBudget(500,0.5,1.0,5.0)-2.5)<1e-9,"percentage cap protects smaller equity");
   Check(SB_NetProfitAllows(5.5,0.5,5.0),"minimum planned net profit accepted");
   Check(!SB_NetProfitAllows(5.49,0.5,5.0),"insufficient planned net profit refused");
   Check(MathAbs(SB_AdaptiveRewardRisk(1.6,3.0,68,68,0,false)-1.6)<1e-9,"adaptive TP keeps base at minimum quality");
   double weakRR=SB_AdaptiveRewardRisk(1.6,3.0,72,68,0.2,false);
   double strongRR=SB_AdaptiveRewardRisk(1.6,3.0,92,68,0.8,false);
   Check(strongRR>weakRR && strongRR<=3.0,"strong market receives farther TP");
   Check(SB_AdaptiveRewardRisk(1.6,3.0,72,68,0.2,true)>weakRR,"structural setup receives measured premium");
   Check(MathAbs(SB_MarketRewardRisk(1,1,102,2,101,99,0,0,1.8,3.0)-1.8)<1e-9,"near breakout target does not reduce quality TP");
   Check(MathAbs(SB_MarketRewardRisk(1,1,101.2,1,101,99,0,0,1.8,3.0)-1.8)<1e-9,"breakout measured move respects quality floor");
   double springTargetRR=SB_MarketRewardRisk(2,1,101,1,0,0,104,100,1.8,3.0);
   Check(MathAbs(springTargetRR-3.0)<1e-8,"Spring uses opposite range boundary with RR cap");
   Check(SB_MarketRewardRisk(1,0,100,1,101,99,0,0,1.8,3.0)==0,"invalid adaptive target direction refused");
   Check(MathAbs(SB_Price(100.13,0.25,2,false)-100.0)<1e-9,"price rounds down on tick grid");
   Check(MathAbs(SB_Price(100.13,0.25,2,true)-100.25)<1e-9,"price rounds up on tick grid");
   Check(SB_Price(100,0,2,false)==0,"missing tick size");
   int streak=0; bool blocked=false;
   SB_Loss(-1,3,streak,blocked); SB_Loss(-1,3,streak,blocked);
   Check(streak==2 && !blocked,"two losses do not suspend");
   SB_Loss(-1,3,streak,blocked); Check(streak==3 && blocked,"third loss suspends");
   SB_Loss(1,3,streak,blocked); Check(blocked,"daily latch survives later gain");
   streak=0; blocked=false;
   SB_Loss(-1,3,streak,blocked); Check(streak==1 && !blocked,"new day counter restarts");
   SB_Loss(0,3,streak,blocked); Check(streak==0,"flat trade breaks loss sequence");
   datetime pauseUntil=0,sequenceStart=D'2026.09.08 00:00:00'; streak=0;
   SB_LossSequence(-1,D'2026.09.08 10:00:00',3,86400,streak,pauseUntil,sequenceStart);
   SB_LossSequence(-1,D'2026.09.09 10:00:00',3,86400,streak,pauseUntil,sequenceStart);
   Check(streak==2 && pauseUntil==0,"loss sequence crosses server days");
   SB_LossSequence(-1,D'2026.09.10 10:00:00',3,86400,streak,pauseUntil,sequenceStart);
   Check(streak==0 && pauseUntil==D'2026.09.11 10:00:00',"third loss starts configured pause");
   Check(sequenceStart==pauseUntil,"new sequence starts after pause");
   SB_LossSequence(-1,D'2026.09.10 12:00:00',3,86400,streak,pauseUntil,sequenceStart);
   Check(streak==0,"loss during pause cannot seed next sequence");
   SB_LossSequence(-1,D'2026.09.11 11:00:00',3,86400,streak,pauseUntil,sequenceStart);
   Check(streak==1,"loss after pause starts fresh sequence");
   Check(SB_Day(D'2026.09.09 23:59:59')==D'2026.09.09 00:00:00',"server day floor");
   Check(SB_Day(D'2026.09.10 00:00:00')!=SB_Day(D'2026.09.09 23:59:59'),"midnight transition");
   Check(SB_EntrySession(5,14,7,20,true,true,15),"Friday entry before cutoff");
   Check(!SB_EntrySession(5,15,7,20,true,true,15),"Friday entry blocked at cutoff");
   Check(!SB_EntrySession(5,14,7,20,true,false,15),"Friday disabled entirely");
   Check(!SB_FridayClose(5,19,20) && SB_FridayClose(5,20,20),"Friday close threshold");
   Check(SB_DataRetryAllowed(D'2026.09.10 10:00:00',0,D'2026.09.10 10:00:01',0,true),"first warmup attempt allowed");
   Check(!SB_DataRetryAllowed(D'2026.09.10 10:00:00',D'2026.09.10 10:00:00',D'2026.09.10 10:30:00',0,true),"warmup retries only on a new bar");
   Check(SB_DataRetryAllowed(D'2026.09.10 11:00:00',D'2026.09.10 10:00:00',D'2026.09.10 11:00:01',D'2026.09.10 12:00:00',true),"new bar releases warmup retry");
   Check(!SB_DataRetryAllowed(D'2026.09.10 10:00:00',D'2026.09.10 10:00:00',D'2026.09.10 10:00:30',D'2026.09.10 10:01:00',false),"transient retry delay enforced");
   Check(SB_DataRetryAllowed(D'2026.09.10 10:00:00',D'2026.09.10 10:00:00',D'2026.09.10 10:01:00',D'2026.09.10 10:01:00',false),"transient retry resumes after delay");
   Check(SB_RiskScale(1,2,8,0.5)==1.0,"full risk below drawdown reduction threshold");
   Check(MathAbs(SB_RiskScale(5,2,8,0.5)-0.75)<1e-9,"risk reduces linearly in drawdown");
   Check(SB_RiskScale(8,2,8,0.5)==0.5,"minimum risk scale at drawdown stop");
   Check(MathAbs(SB_DirectionalEfficiency(5,10)-0.5)<1e-9,"directional efficiency measured");
   Check(SB_DirectionalEfficiency(5,0)==0,"invalid path has zero efficiency");
   Check(MathAbs(SB_CloseStrength(1,110,100,108)-0.8)<1e-9,"bullish close strength");
   Check(MathAbs(SB_CloseStrength(-1,110,100,102)-0.8)<1e-9,"bearish close strength");
   Check(SB_SetupScore(true,2,1.1,4,0.8,0.6,false)>=68,"aligned quality setup accepted");
   Check(SB_SetupScore(true,4.1,1.1,4,1,1,false)==0,"climactic volume vetoes setup");
   Check(SB_SetupScore(false,1.5,1,4,0.8,0.6,true)>0,"neutral structural setup remains measurable");
   Check(SB_VolumeScore(1.1,1.1,4)==0,"volume score starts at zero on minimum veto boundary");
   Check(SB_VolumeScore(2.0,1.1,4)<SB_VolumeScore(3.0,1.1,4),"volume score is monotone");
   Check(SB_VolumeScore(4.0,1.1,4)==20,"volume score is bounded at twenty");
   Check(SB_SetupScore(true,2,1.1,4,0.8,0.6,false)==SB_SetupScore(true,2,1.1,4,0.8,0.6,true),"engines share a comparable score scale");
   Check(SB_PatternInvalidated(1,1,99.8,100,95,0,0,0.1),"buy breakout re-entry invalidates pattern");
   Check(!SB_PatternInvalidated(1,1,100.2,100,95,0,0,0.1),"buy breakout acceptance remains valid");
   Check(SB_PatternInvalidated(2,1,98.9,0,0,105,100,0.1),"Spring acceptance below range invalidates");
   Check(SB_PatternInvalidated(3,-1,106.1,0,0,105,100,0.1),"Upthrust acceptance above range invalidates");
   Check(!SB_PatternInvalidated(1,-1,90,0,0,0,0,0.1),"missing persisted structure cannot force exit");
   Check(SB_TradingRange(106,100,1,1.5,6.0,3,2,2,0.20,0.35),"balanced range accepted");
   Check(!SB_TradingRange(108,100,1,1.5,6.0,3,3,2,0.20,0.35),"range too wide rejected");
   Check(!SB_TradingRange(106,100,1,1.5,6.0,1,3,2,0.20,0.35),"range needs repeated boundary touches");
   Check(!SB_TradingRange(106,100,1,1.5,6.0,3,3,2,0.50,0.35),"directional drift rejects range");
   Check(SB_SpringPattern(106,100,1,101,102,99.8,100.5,100.4,101.5,100.2,101.2,
                          0.05,1.0,1.2,1.0)==1,"confirmed Spring recognized");
   Check(SB_SpringPattern(106,100,1,101,102,99.8,100.5,100.4,101,99.7,99.9,
                          0.05,1.0,1.2,1.0)==-2,"failed Spring recognized");
   Check(SB_SpringPattern(106,100,1,105,106.3,104,105.5,105.6,105.8,104.8,105.0,
                          0.05,1.0,1.2,1.0)==-1,"confirmed Upthrust recognized");
   Check(SB_SpringPattern(106,100,1,105,106.3,104,105.5,105.6,106.4,105.4,106.2,
                          0.05,1.0,1.2,1.0)==2,"failed Upthrust recognized");
   Check(SB_SpringPattern(106,100,1,101,102,99.8,100.5,100.4,101.5,100.2,101.2,
                          0.05,1.0,0.8,1.0)==0,"weak-volume Spring rejected");
   Check(!SB_Tightens(1,99,98,99),"buy SL cannot widen");
   Check(SB_Tightens(1,99,100,99),"buy break even tightens");
   Check(!SB_Tightens(-1,101,102,101),"sell SL cannot widen");
   Check(SB_Tightens(-1,101,100,101),"sell break even tightens");
   Check(SB_Tightens(-1,0,101,101),"restore missing sell SL");
   double base=SB_Score(100,1000,1.4,3,150,150,0.2);
   Check(SB_Score(100,1000,1.4,8,150,150,0.2)<base,"drawdown score penalty");
   Check(SB_Score(100,1000,1.4,3,10,150,0.2)<base,"small sample score penalty");
   Check(SB_Score(100,1000,1.1,3,150,150,0.2)<base,"low PF score penalty");
   Check(SB_Score(100,1000,1.4,3,150,150,0.9)<base,"concentration score penalty");
   Check(SB_Score(0,1000,0,0,0,150,1)==-1000000,"no trades rejected");
   int file=FileOpen("SB3-test-results.txt",FILE_WRITE|FILE_TXT);
   if(file!=INVALID_HANDLE) { FileWrite(file,StringFormat("PASS=%d FAIL=%d",Passed,Failed)); FileClose(file); }
   PrintFormat("SB3_TEST_RESULT | PASS=%d FAIL=%d",Passed,Failed);
}
