# FactSet_Holdings
This repository contains SAS code that produces the same results as its companion postgreSQL code
- Step1A:Aggregates 13F and fund-level reports in FactSet at the security level to quarterly holdings, dollar holdings

- Step1B:Calculates institution portfolio-level characteristics.

- Step2:Aggregate holdings to security-level and firm-level ownership.

- Step0 compiles identifiers in FactSet for funds, institutions, companies and securities.

- functions.sql includes helper functions

- Auxiliaries2023.sql includes helper tables


The data cleaning procedure follows the SAS code of Ferreira and Matos (2008, JFE):

1. Last available reports are rolled over to fill in missing report if it is less than 8 quarters old. 

2. Fills in missing reports if the most recent report was filled after T-3

3. When both 13F reports and fund reports are available for a institution-security-quarter observation, use 13F for US securities, use the maximum holding of 13F and fund reports for non-US securities.

Amendment to Ferreira and Matos:

- Portfolio characteristics including AUM and number of securities across investment destinations (domestic, foreign DM, foreign EM) HHI, active share (Koijen et al 2023, RES), home bias (Bekaert and Wang, 2008), churn ratio (Stark et al 2023), investment horizon and portfolio concentration (Prado et al 2016, RFS)

- Optional filters a la Camanho et al (2022)