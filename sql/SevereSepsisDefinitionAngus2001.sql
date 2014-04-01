create table "MAYAUDLO".SevereSepsisIDAngus2001_Vent as
with infectionPopulation as ( --ALL INFECTION CODES ACCORDING TO ANGUS
SELECT    h.subject_ID,
          h.hadm_id   
  FROM mimic2v26.admissions h, 
       mimic2v26.ICD9 code
  WHERE code.SUBJECT_ID = h.SUBJECT_ID 
        and ( substr( code.CODE , 1 , 3 ) in (  
         '001' -- Cholera; 
        ,  '002'  --Typhoid/paratyphoid fever; 
        , '003'  --Other salmonella infection; 
        , '004'  --Shigellosis; 
        , '005'  --Other foodpoisoning; 
        , '008'  --Intestinal infection nototherwise classiﬁed;
        , '009'  -- Ill-deﬁned intestinal infection; 
        , '010'  --Primary tuberculosis infection; 
        , '011'  --Pulmonary tuberculosis; 
        , '012'  --Other respiratory tuberculosis;
        , '013'  --Central nervous system tuberculosis; 
        , '014'  --Intestinal tuberculosis; 
        , '015'  --Tuberculosis of bone or joint; 
        , '016'  --Genitourinary tuberculosis; 
        , '017'  --Tuberculosisnot otherwise classiﬁed; 
        , '018'  --Miliary tuberculosis; 
        , '020'  --Plague; 
        , '021'  --Tularemia;
        , '022'  --Anthrax; 
        , '023'  --Brucellosis; 
        , '024'  --Glorers; 
        , '025'  --Melioidosis; 
        , '026'  --Rat-bite fever;
        , '027'  --Other bacterial zoonoses; 
        , '030'  --Leprosy; 
        , '031'  --Other mycobacterial disease;
        , '032'  --Diphtheria; 
        , '033'  --Whooping cough;
        , '034'  --Streptococcal throat/scarlet fever;
        , '035'  --Erysipelas; 
        , '036'  --Meningococcal infection; 
        , '037'  --Tetanus; 
        , '038'  --Septicemia;
        , '039'  --Actinomycotic infections; 
        , '040'  --Other bacterial diseases; 
        , '041'  --Bacterial infectionin other diseases not otherwise speciﬁed;
        , '090'  --Congenital syphilis; 
        , '091'  --Earlysymptomatic syphilis; 
        , '092'  --Early syphilislatent; 
        , '093'  --Cardiovascular syphilis; 
        , '094' --Neurosyphilis; 
        , '095'  --Other late symptomatic syphilis; 
        , '096'  --Late syphilis latent;
        , '097'  --Other and unspeciﬁed syphilis; 
        , '098' --Gonococcal infections; 
        , '100'  --Leptospirosis; 
        , '101'  --Vincent’s angina; 
        , '102'  --Yaws; 
        , '103' --Pinta; 
        , '104'  --Other spirochetal infection;
        , '110' -- Dermatophytosis; 
        , '111'  --Dermatomycosis not otherwise classiﬁed or speciﬁed;
        , '112' -- Coridiasis; 
        , '114'  --Coccidioidomycosis; 
        , '115' -- Histoplasmosis; 
        , '116'  --Blastomycotic infection; 
        , '117'  --Other mycoses; 
        , '118' --Opportunistic mycoses; 
        , '320'  --Bacterialmeningitis; 
        , '322'  --Meningitis  unspeciﬁed;
        , '324'  --Central nervous system abscess; 
        , '325' --Phlebitis of intracranial sinus; 
        , '420'  --Acutepericarditis; 
        , '421'  --Acute or subacute endocarditis; 
        , '451'  --Thrombophlebitis;
        , '461' --Acute sinusitis;
        , '462'  --Acute pharyngitis;
        , '463' -- Acute tonsillitis; 
        , '464'  --Acute laryngitis/tracheitis;
        , '465'  --Acute upper respiratory infection of multiple sites/not otherwisespeciﬁe d ; 
        , '481' --  P n e umo c o c c a lpneumonia; 
        , '482'  --Other bacterial pneumonia; 
        , '485'  --Bronchopneumonia with organism not otherwise speciﬁed; 
        , '486' --Pneumonia  organism not otherwisespeciﬁed; 
        , '494' --Bronchiectasis; 
        , '510'  --Empyema; 
        , '513' --Lung/mediastinum abscess; 
        , '540'  --Acuteappendicitis; 
        , '541'  --Appendicitis not otherwise speciﬁed; 
        , '542'  --Other appendicitis;
        , '566'  --Anal or rectal abscess; 
        , '567'  --Peritonitis; 
        , '590'  --Kidney infection; 
        , '597'  --Urethritis/urethral syndrome; 
        , '601' --Prostatic inﬂammation;
        , '614'  --Female pelvic inﬂammation disease; 
        , '615'  --Uterine in-ﬂammatory disease; 
        , '616'  --Other femalegenital inﬂammation;
        , '681'  --Cellulitis  ﬁnger/toe; 
        , '682'  --Other cellulitis or abscess;
        , '683'  --Acute lymphadenitis;
        , '686'  --Other local skin infection; 
        , '730'  --Osteomyelitis; 
        )
        or substr( code.CODE , 1, 6) in (       
         '491.21' -- Acute exacerbation ofobstructive chronic bronchitis; 
        , '562.01' -- Diverticulitis of small intestinewithout hemorrhage; 
        , '562.03'  --Diverticulitis of small intestine with hemorrhage;
        , '562.11'  --Diverticulitis of colon withouthemorrhage; 
        , '562.13'  --Diverticulitis of colon with hemorrhage; 
        , '569.83' -- Perforation ofintestine; 
       )
       or substr( code.CODE , 1, 5) in (       
         '569.5' -- Intestinal abscess; 
        , '572.0'  --Abscess of liver; 
        , '572.1' --Portal pyemia;
        , '575.0'  --Acute cholecystitis;
        , '599.0'  --Urinary tractinfection not otherwise speciﬁed; 
        , '711.0'  --Pyogenic arthritis; 
        , '790.7'  --Bacteremia; 
        , '996.6'  --Infection or inﬂammation ofdevice/graft; 
        , '998.5'  --Postoperative infection; 
        , '999.3'  --Infectious complication ofmedical care not otherwise classiﬁed. 
        )
    )  
)

, anguspopulation as (
SELECT    h.subject_ID,
          h.hadm_id   
  FROM infectionPopulation h, 
       mimic2v26.ICD9 code
  WHERE code.SUBJECT_ID = h.SUBJECT_ID     -- INFECTION + ORGAN FAILURE
    AND ( code.CODE like '785.5%' -- Cardiovascular Shock without trauma
        or code.CODE like '458%' -- Hypotension
        or code.CODE like '348.3%' -- Neurologic Encephalopathy 
        or code.CODE like '293%' -- Transient organic psychosis 
        or code.CODE like '348.1%' -- Anoxic brain damage 
        or code.CODE like '287.4%' -- Hematologic Secondary thrombocytopenia 
        or code.CODE like '287.5%' -- Thrombocytopenia, unspeciﬁed
        or code.CODE like '286.9%' -- Other/unspeciﬁed coagulation defect
        or code.CODE like '286.6%' -- Deﬁbrination syndrome
        or code.CODE like '570%' -- Hepatic Acute and subacute necrosis of liver
        or code.CODE like '573.4%' -- Hepatic infarction
        or code.CODE like '584%' -- Renal Acute renal failure 
        ) 
union     -- JOIN WITH MECH VENT+INFECTION patients
SELECT    ip.hadm_id, 
          ip.subject_ID
  FROM infectionPopulation ip,
       mimic2v26.procedureevents code
  WHERE   ip.subject_id = code.subject_id 
         and ip.hadm_id = code.hadm_id         
    AND   code.itemid in (  101729, -- NON Invasive Respiratory Mechanical ventilation
                            101781, -- Invasive Respiratory Mechanical ventilation
                            101782,  -- Invasive Respiratory Mechanical ventilation
                            101783) -- Invasive Respiratory Mechanical ventilation
        
)

select distinct * 
  from anguspopulation
;
select  count(unique subject_id )
from severesepsisidangus2001

;

select subject_id,hadm_id,icustay_id,icustay_intime from MIMIC2V26.icustay_detail
where subject_id = 68
order by subject_id,hadm_id,icustay_id,icustay_intime


;
select * organFailurePopulation
union
select * organFailurePopulationProc
  
select  unique ip.hadm_id,
        ip.subject_id
  from  organFailurePopulation oFp, 
        infectionPopulation ip
        organFailurePopulationProc oFpp
  where  oFp.hadm_id = ip.hadm_id
    or  oFpp.hadm_id = ip.hadm_id
  
  ;
  
 
 
  MERGE 
       INTO  SevereSepsisIDMartin2003 a
       USING SevereSepsisIDMartin2003p ap
       ON   (ap.hadm_id = a.hadm_id)
    WHEN MATCHED
    THEN
       UPDATE
       SET a.subject_id = ap.subject_id
    WHEN NOT MATCHED
   THEN
      INSERT (a.subject_id, a.hadm_id)
      VALUES (ap.subject_id, ap.hadm_id);

  
  ;
  
  select count(unique subject_id)
  from "MAYAUDLO".SepsicShockICD9
  ;
  -- Select for specific codes
  select  code,
          description
  from mimic2v26.D_CODEDITEMS
  where code like '%967%'
  group by code, description
  order by code
  
  ;
  -- septic shock codes only
  create table "MAYAUDLO".SepsicShockICD9 as
  select adm.subject_id,
         adm.hadm_id
  from  MIMIC2V26.admissions adm,
        MIMIC2V26.icd9 code 
  where  adm.hadm_id = code.hadm_id
        and code.CODE = '785.52'
        
 ; 
 -- compare definition of severe sepsis
  
  select count(unique icd.subject_id)
  from severesepsisidangus2001 ang,
        severesepsisidmartin2003 mar,
       sepsicshockicd9 icd
  where ang.subject_id = mar.subject_id
    and icd.subject_id = ang.subject_id
    and mar.subject_id = icd.subject_id
