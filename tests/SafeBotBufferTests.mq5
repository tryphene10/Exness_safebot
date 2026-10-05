#property strict
// Model lazy calculation: BarsCalculated stays zero until CopyBuffer is called.
int Copies=0,Calculated=0,Mode=0;
int FakeBarsCalculated(int handle) { return Calculated; }
int FakeCopyBuffer(int handle,int buffer,int shift,int count,double &values[])
{
   Copies++;
   if(Mode==1) return -1;
   ArrayResize(values,count); Calculated=count+1;
   for(int k=0;k<count;k++) values[k]=(Mode==2 ? EMPTY_VALUE : 1.0+k);
   return Mode==3 ? count-1 : count;
}
#define CopyBuffer FakeCopyBuffer
#define BarsCalculated FakeBarsCalculated
#define OnInit UnusedInit
#define OnDeinit UnusedDeinit
#define OnTick UnusedTick
#define OnTimer UnusedTimer
#define OnTradeTransaction UnusedTransaction
#define OnTester UnusedTester
#include "../ExnessSafeBot.mq5"
int Passed=0,Failed=0;
void Check(bool ok,string name) { if(ok) Passed++; else Failed++; PrintFormat("BUFFER_TEST | %s | %s",ok ? "PASS" : "FAIL",name); }
void OnStart()
{
   double values[]; string error="";
   bool oldOK=FakeBarsCalculated(1)>=4 && FakeCopyBuffer(1,0,1,3,values)==3;
   Check(!oldOK && Copies==0,"old gate starves lazy calculation");
   Check(Buffer(1,3,values,error) && Copies==1,"cold indicator is requested before readiness check");
   Mode=1; Check(!Buffer(1,3,values,error) && StringFind(error,"copied=-1")>=0,"copy failure diagnosed");
   Mode=2; Check(!Buffer(1,3,values,error) && StringFind(error,"invalid")>=0,"empty values refused");
   Mode=3; Check(!Buffer(1,3,values,error),"partial buffer refused");
   Mode=0; Check(Buffer(1,3,values,error),"retry succeeds after data arrival");
   bool ready=false; int before=Copies;
   ready=NamedBuffer(1,3,values,"test",error) && ready;
   Check(Copies==before+1 && !ready,"request not skipped after previous failure");
   int f=FileOpen("SB3-buffer-tests.txt",FILE_WRITE|FILE_TXT);
   if(f!=INVALID_HANDLE) { FileWrite(f,StringFormat("PASS=%d FAIL=%d",Passed,Failed)); FileClose(f); }
}
