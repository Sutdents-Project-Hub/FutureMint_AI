-- The declaration method records consent, not verified identity.
ALTER TABLE service_eligibilities
  ADD COLUMN guardian_consent_method text
  CHECK (guardian_consent_method IN ('email', 'in-app'));

UPDATE service_eligibilities
SET guardian_consent_method = 'email'
WHERE guardian_status = 'approved' AND guardian_email IS NOT NULL;
