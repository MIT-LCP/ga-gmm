with cohort as (
  select cd.icustay_id
  , ca.*
  , cd.icustay_intime
  from MIMIC2V26.icustay_detail cd
    on cd.subject_id=ca.subject_id
    and cd.hadm_id=ca.hadm_id
)