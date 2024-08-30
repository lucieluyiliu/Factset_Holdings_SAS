/*Convert to local encoding format*/


/*check encoding format*/

proc options option=encoding define;
run;


options dlcreatedir;
libname factset ('S:/factset/own_v5','S:/factset/common');
libname fswork 'S:/FSWORK/';
libname sasuser '~/sasuser.v94';
%include 'D:/factset_holdings/auxiliaries2024.sas';
%include 'D:/factset_holdings/functions.sas';
%let exportfolder=S:/FSWORK/; 

data factset.edm_standard_entity;
set factset.edm_standard_entity  (encoding='any');
run;

data factset.own_sec_prices_eq;
set factset.own_sec_prices_eq (encoding='any');
run;


data factset.own_sec_coverage_eq;
set factset.own_sec_coverage_eq(encoding='any');
run;

data factset.sym_coverage;
set factset.sym_coverage (encoding='any');
run;

data factset.own_sec_entity_eq;
set factset.own_sec_entity_eq (encoding='any');
run;


data factset.own_inst_13f_detail_eq;
set factset.own_inst_13f_detail_eq (encoding='any');
run;

data factset.own_fund_detail_eq;
set factset.own_fund_detail_eq (encoding='any');
run;
