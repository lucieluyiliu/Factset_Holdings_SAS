/*Functions*/

proc fcmp outlib=work.myfuncs.lionshares;
			function quarter_add(q,x);
				myear = int(q/100);
				mquarter = mod(q,10);
				years = floor(x/4);
				quarters = (x - 4 * years);
				if mquarter + quarters > 4 then result = (myear + years + 1)*100 + (mquarter + quarters - 4);
				else result = (myear + years)*100+(mquarter + quarters);
			return(result);
			endsub;
	run;
	quit;
	

/*add semi-year*/	
proc fcmp outlib=work.myfuncs.lionshares;
			function semiyear_add(yyyyhh,x);
				myear = int(yyyyhh/100);
				mhalf = mod(yyyyhh,10);
				years = floor(x/2);
				halves = (x - 2 * years);
				if mhalf + halves > 2 then result = (myear + years + 1)*100 + (mhalf + halves - 2);
				else result = (myear + years)*100+(mhalf + halves);
			return(result);
			endsub;
run;
quit;

options cmplib=work.myfuncs;

/*add month*/

proc fcmp outlib=work.myfuncs.lionshares;
			function month_add(yyyymm,x);
				myear = int(yyyymm/100);
				mmonth = mod(yyyymm,100);
				years = floor(x/12);
				months = (x - 12 * years);
				if mmonth + months > 12 then result = (myear + years + 1)*100 + (mmonth + months - 12);
				else result = (myear + years)*100+(mmonth + months);
			return(result);
			endsub;
run;
quit;



