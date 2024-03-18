proc sql;
create table dlc
(dlc_entity_id char(8),
 factset_entity_id char(8),
 dlc_name char(32));

 

proc sql;
create table inst_type
(entity_sub_type char(2),
 entity_description char(32),
 cat_institution num,
 cat_institution_desc char(20),
 is_active num);
quit;


proc sql;
insert into dlc
values ('000VLZ-E','05K2VT-E','Rio Tinto Plc')
values ('05HF13-E','0010VG-E','BHP Billiton Plc')
values ('002118-E','05HWCR-E','Reed Elsevier Plc')
values ('002BV8-E','05DZG8-E','Unilever Plc')
values ('003L8C-E','05K3JK-E','Brambles Industries Plc')
values ('0B0D2Q-E','066L2H-E','Royal Dutch Shell Plc')
values ('05DZH3-E','066L2H-E','Royal Dutch Shell Plc')
values ('05DZFJ-E','066L2H-E','Royal Dutch Shell Plc')
values ('00C390-E','003GTW-E','Carnival Corp.')
;

proc sql;
insert into inst_type 
values('MM','Market Maker',1,'Broker',1)
values('BM','Bank Management Division',1,'Broker',1)
values('IB','Investment Banking',1,'Broker',1)
values('ST','Stock borrowing/lending',1,'Broker',1)
values('BR','Broker',1,'Broker',1)
values('CP','Corporate',2,'Private Banking',0)
values('CU','Custodial',2,'Private Banking',1)
values('VC','Venture capital/Pvt equity',2,'Private Banking',1)
values('PB','Private Banking Portfolio',2,'Private Banking',1)
values('FY','Family Office',2,'Private Banking',1)
values('FH','Fund of Hedge Funds Manager',3,'Hedge Fund',1)
values('FF','Fund of Funds Manager',3,'Hedge Fund',1)
values('FU','Fund',3,'Hedge Fund',1)
values('AR','Arbitrage',3,'Hedge Fund',1)
values('HF','Hedge Fund Company',3,'Hedge Fund',1)
values('FS','Fund Distributor',3,'Hedge Fund',1)
values('IA','Investment Advisor',4,'Investment Advisor',1)
values('IC','Investment Company',4,'Investment Advisor',1)
values('RE','Research Firm',4,'Investment Advisor',1)
values('PP','Real estate manager',4,'Investment Advisor',1)
values('SB','Subsidiary Branch',4,'Investment Advisor',1)
values('MF','Mutual fund manager',4,'Investment Advisor',1)
values('ML','Master Ltd part',4,'Investment Advisor',1)
values('FO','Foundation/Endowment Manager',5,'Long-term',0)
values('SV','Sovereign Wealth Manager',5,'Long-term',0)
values('IN','Insurance company',5,'Long-term',0)
values('PF','Pension funds',5,'Long-term',0)
values('GV','Government/Fed/local/agency',6,'Government',0)
values('','Others',7,'Other stakeholders',0);
quit;

proc sql;
create table ctry
(ctry char(32),
 iso char(2),
 iso3 char(3),
region char(32),
isem char(2));

quit;
 proc sql;
create table common_law
(ctry char(32),
 iso char(2),
 common_law num);


proc sql;
insert into ctry
values('ARGENTINA','AR','ARG','Latin America','EM')
values('AUSTRALIA','AU','AUS','Developed Asia Pacific','DM')
values('AUSTRIA','AT','AUT','Developed Europe','DM')
values('BELGIUM','BE','BEL','Developed Europe','DM')
values('BRAZIL','BR','BRA','Latin America','EM')
values('CANADA','CA','CAN','North America','DM')
values('CHILE','CL','CHL','Latin America','EM')
values('CHINA','CN','CHN','Emerging Asia','EM')
values('COLOMBIA','CO','COL','Latin America','EM')
values('CZECHIA','CZ','CZE','Emerging EMEA','EM')
values('DENMARK','DK','DNK','Developed Europe','DM')
values('EGYPT','EG','EGY','Emerging EMEA','EM')
values('FINLAND','FI','FIN','Developed Europe','DM')
values('FRANCE','FR','FRA','Developed Europe','DM')
values('GERMANY','DE','DEU','Developed Europe','DM')
values('GREECE','GR','GRC','Emerging EMEA','EM')
values('HONG KONG','HK','HKG','Developed Asia Pacific','DM')
values('HUNGARY','HU','HUN','Emerging EMEA','EM')
values('INDIA','IN','IND','Emerging Asia','EM')
values('INDONESIA','ID','IDN','Emerging Asia','EM')
values('IRELAND','IE','IRL','Developed Europe','DM')
values('ISRAEL','IL','ISR','Emerging EMEA','DM')
values('ITALY','IT','ITA','Developed Europe','DM')
values('JAPAN','JP','JPN','Developed Asia Pacific','DM')
values('KUWAIT','KW','KWT','Emerging EMEA','EM')
values('LUXEMBOURG','LU','LUX','Developed Europe','DM')
values('MALAYSIA','MY','MYS','Emerging Asia','EM')
values('MEXICO','MX','MEX','Latin America','EM')
values('MOROCCO','MA','MAR','Emerging EMEA','FM')
values('NETHERLANDS','NL','NLD','Developed Europe','DM')
values('NEW ZEALAND','NZ','NZL','Developed Asia Pacific','DM')
values('NORWAY','NO','NOR','Developed Europe','DM')
values('PAKISTAN','PK','PAK','Emerging Asia','EM')
values('PERU','PE','PER','Latin America','FM')
values('PHILIPPINES','PH','PHL','Emerging Asia','EM')
values('POLAND','PL','POL','Emerging EMEA','EM')
values('PORTUGAL','PT','PRT','Developed Europe','DM')
values('QATAR','QA','QAT','Emerging EMEA','EM')
values('ROMANIA','RO','ROU','Emerging EMEA','EM')
values('RUSSIA','RU','RUS','Emerging EMEA','EM')
values('SAUDI ARABIA','SA','SAU','Emerging EMEA','EM')
values('SINGAPORE','SG','SGP','Developed Asia Pacific','DM')
values('SOUTH AFRICA','ZA','ZAF','Emerging EMEA','EM')
values('SOUTH KOREA','KR','KOR','Emerging Asia','EM')
values('SPAIN','ES','ESP','Developed Europe','DM')
values('SWEDEN','SE','SWE','Developed Europe','DM')
values('SWITZERLAND','CH','CHE','Developed Europe','DM')
values('TAIWAN','TW','TWN','Emerging Asia','EM')
values('THAILAND','TH','THA','Emerging Asia','EM')
values('TURKIYE','TR','TUR','Emerging EMEA','EM')
values('UNITED ARAB EMIRATES','AE','ARE','Emerging EMEA','EM')
values('UNITED KINGDOM','GB','GBR','Developed Europe','DM')
values('USA','US','USA','North America','DM')
;


proc sql;
insert into common_law
values('AUSTRALIA','AU',1)
values('CANADA','CA',1)
values('HONG KONG','HK',1)
values('INDIA','IN',1)
values('IRELAND','IE',1)
values('ISRAEL','IL',1)
values('KENYA','KE',1)
values('MALAYSIA','MY',1)
values('NEW ZEALAND','NZ',1)
values('NIGERIA','NG',1)
values('PAKISTAN','PK',1)
values('SINGAPORE','SG',1)
values('SOUTH AFRICA','ZA',1)
values('SRI LANKA','LK',1)
values('THAILAND','TH',1)
values('UNITED KINGDOM','GB',1)
values('USA','US',1)
values('ZIMBABWE','ZW',1);



