-- Seed Data for Manas360 Database

-- 1. Users
INSERT INTO users (id, email, phone, password_hash, role) VALUES 
('u1111111-1111-4111-a111-111111111111', 'admin@manas360.com', '1234567890', 'hash', 'admin'),
('u2222222-2222-4222-a222-222222222222', 'therapist1@manas360.com', '1234567891', 'hash', 'therapist'),
('u3333333-3333-4333-a333-333333333333', 'patient1@manas360.com', '1234567892', 'hash', 'patient'),
('u4444444-4444-4444-a444-444444444444', 'doctor1@hospital.com', '1234567893', 'hash', 'referring_doctor')
ON CONFLICT (email) DO NOTHING;

-- 2. Doctor Profiles
INSERT INTO doctor_profiles (id, user_id, full_name, doctor_code, specialization, referral_tier, verification_status) VALUES
('d1111111-1111-4111-b111-111111111111', 'u4444444-4444-4444-a444-444444444444', 'Dr. Ramesh Kumar', 'DR-KA-0001', 'Cardiologist', 'bronze', 'verified')
ON CONFLICT DO NOTHING;

-- 3. Therapist Profiles
INSERT INTO therapist_profiles (id, user_id, full_name, primary_specialization, session_rate_inr) VALUES
('t1111111-1111-4111-c111-111111111111', 'u2222222-2222-4222-a222-222222222222', 'Aruna Sharma', 'CBT Specialist', 1500)
ON CONFLICT DO NOTHING;

-- 4. Patients
INSERT INTO patients (patient_id, user_id, full_name, referred_by_doctor) VALUES
('p1111111-1111-4111-d111-111111111111', 'u3333333-3333-4333-a333-333333333333', 'John Doe', 'd1111111-1111-4111-b111-111111111111')
ON CONFLICT DO NOTHING;

-- 5. Doctor Referrals
INSERT INTO doctor_referrals (doctor_id, doctor_code, session_id, status, lifetime_value) VALUES
('d1111111-1111-4111-b111-111111111111', 'DR-KA-0001', 'sess_abc123', 'subscribed', 5000)
ON CONFLICT DO NOTHING;

-- 6. Doctor Credits
INSERT INTO doctor_credits (doctor_id, credits, credit_type, base_credits, multiplier, description) VALUES
('d1111111-1111-4111-b111-111111111111', 100, 'signup', 100, 1.0, 'Incentive for first referral signup')
ON CONFLICT DO NOTHING;

-- 7. Sessions
INSERT INTO sessions (patient_id, therapist_id, session_type, mode, status, fee_inr) VALUES
('p1111111-1111-4111-d111-111111111111', 't1111111-1111-4111-c111-111111111111', 'therapy', 'online', 'completed', 1500)
ON CONFLICT DO NOTHING;

-- 8. CBT Session Data
INSERT INTO cbt_session_data (session_id, activity_type, step_number, prompt_title, client_input) VALUES
((SELECT id FROM sessions LIMIT 1), 'thought_record', 1, 'What happened?', 'I felt anxious before the meeting.')
ON CONFLICT DO NOTHING;

-- 9. Assessments
INSERT INTO assessments (patient_id, assessment_type, phq9_score, gad7_score, phq9_severity) VALUES
('p1111111-1111-4111-d111-111111111111', 'phq9', 12, 8, 'Moderate')
ON CONFLICT DO NOTHING;

-- 10. Certificates
INSERT INTO certificates (patient_id, therapist_id, certificate_type, program_name, issued_at) VALUES
('p1111111-1111-4111-d111-111111111111', 't1111111-1111-4111-c111-111111111111', 'cbt_program_completion', 'Anxiety Relief Program', NOW())
ON CONFLICT DO NOTHING;

-- 11. Leads
INSERT INTO leads (assessment_id, patient_id, therapist_id, match_score, status) VALUES
((SELECT id FROM assessments LIMIT 1), 'p1111111-1111-4111-d111-111111111111', 't1111111-1111-4111-c111-111111111111', 85.5, 'converted')
ON CONFLICT DO NOTHING;

-- 12. Transactions
INSERT INTO transactions (user_id, patient_id, amount_inr, status, transaction_type) VALUES
('u3333333-3333-4333-a333-333333333333', 'p1111111-1111-4111-d111-111111111111', 1500, 'captured', 'session')
ON CONFLICT DO NOTHING;

-- 13. Audit Logs
INSERT INTO audit_logs (user_id, entity_type, action) VALUES
('u1111111-1111-4111-a111-111111111111', 'user', 'login')
ON CONFLICT DO NOTHING;

-- 14. Doctor Redemptions
INSERT INTO doctor_redemptions (doctor_id, credits_redeemed, reward_type, status) VALUES
('d1111111-1111-4111-b111-111111111111', 50, 'amazon_voucher', 'completed')
ON CONFLICT DO NOTHING;

-- 15. Doctor Asset Orders
INSERT INTO doctor_asset_orders (doctor_id, order_number, items, total_amount, fulfillment_status) VALUES
('d1111111-1111-4111-b111-111111111111', 'ORD-001', '[{"type": "desk_card", "qty": 1}]', 299.00, 'delivered')
ON CONFLICT DO NOTHING;
