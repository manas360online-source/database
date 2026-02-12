-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

------------------------------------------------------------
-- 1. USERS
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email               VARCHAR(255) NOT NULL UNIQUE,
    phone               VARCHAR(20),
    password_hash       VARCHAR(255) NOT NULL,
    role                VARCHAR(50) NOT NULL,              -- 'patient','therapist','admin','doctor','coach','referring_doctor'
    subscription_tier   VARCHAR(50),                       -- 'free','tier1','tier2',...
    is_email_verified   BOOLEAN DEFAULT FALSE,
    is_phone_verified   BOOLEAN DEFAULT FALSE,
    is_active           BOOLEAN DEFAULT TRUE,
    last_login_at       TIMESTAMP,
    created_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT users_role_check CHECK (role IN ('patient', 'therapist', 'admin', 'doctor', 'coach', 'referring_doctor'))
);

-- Indexes for users
CREATE INDEX IF NOT EXISTS idx_users_phone       ON users(phone);
CREATE INDEX IF NOT EXISTS idx_users_role        ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_created_at  ON users(created_at);

------------------------------------------------------------
-- 2. DOCTOR PROFILES
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS doctor_profiles (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID UNIQUE,                      -- one user ↔ one doctor profile

    full_name           VARCHAR(255) NOT NULL,
    email               VARCHAR(255),
    phone               VARCHAR(20),

    hospital_name       VARCHAR(255),
    specialization      VARCHAR(255),
    registration_number VARCHAR(100),
    registration_council VARCHAR(100),

    city                VARCHAR(100),
    state               VARCHAR(100),
    pincode             VARCHAR(10),

    clinic_phone        VARCHAR(20),
    clinic_email        VARCHAR(255),
    experience_years    INT,
    photo_url           VARCHAR(500),

    doctor_code         VARCHAR(20) UNIQUE,
    credentials         VARCHAR(255),

    verification_status VARCHAR(20) DEFAULT 'pending',
    verified_at         TIMESTAMP,
    verified_by         UUID,
    rejection_reason    TEXT,

    registration_doc_url VARCHAR(500),
    id_proof_url        VARCHAR(500),

    referral_url        VARCHAR(255),
    qr_code_url         VARCHAR(500),
    qr_generated_at     TIMESTAMP,

    notify_on_referral  BOOLEAN DEFAULT TRUE,
    notification_method VARCHAR(20) DEFAULT 'whatsapp',
    referral_tier       VARCHAR(20) DEFAULT 'bronze',

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_doctor_verification_status
        CHECK (verification_status IN ('pending','verified','rejected','suspended')),
    CONSTRAINT chk_doctor_notification_method
        CHECK (notification_method IN ('email','whatsapp','sms','app')),
    CONSTRAINT chk_doctor_referral_tier
        CHECK (referral_tier IN ('bronze','silver','gold','platinum')),
    CONSTRAINT uq_doctor_registration UNIQUE (registration_number, registration_council)
);

-- FKs for doctor_profiles
ALTER TABLE doctor_profiles
    ADD CONSTRAINT fk_doctor_profiles_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE doctor_profiles
    ADD CONSTRAINT fk_doctor_profiles_verified_by
    FOREIGN KEY (verified_by) REFERENCES users(id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_doctor_profiles_city      ON doctor_profiles(city);
CREATE INDEX IF NOT EXISTS idx_doctor_profiles_state     ON doctor_profiles(state);
CREATE INDEX IF NOT EXISTS idx_doctor_profiles_specialty ON doctor_profiles(specialization);
CREATE INDEX IF NOT EXISTS idx_doctor_profiles_status    ON doctor_profiles(verification_status);

------------------------------------------------------------
-- 3. THERAPIST PROFILES
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS therapist_profiles (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID UNIQUE NOT NULL,

    full_name               VARCHAR(255) NOT NULL,
    gender                  VARCHAR(20),
    date_of_birth           DATE,

    nmc_registration        VARCHAR(100),
    registration_council    VARCHAR(100),
    primary_specialization  VARCHAR(100),
    specializations         TEXT,                    -- comma-separated or JSON text

    years_experience        INT,
    bio                     TEXT,
    languages               VARCHAR(255),            -- e.g. "English,Hindi"

    city                    VARCHAR(100),
    state                   VARCHAR(100),
    country                 VARCHAR(100),
    timezone                VARCHAR(100),

    profile_photo_url       VARCHAR(500),
    video_intro_url         VARCHAR(500),

    session_rate_inr        NUMERIC,
    currency                VARCHAR(10),

    is_featureed            BOOLEAN DEFAULT FALSE,
    rating_avg              NUMERIC,
    rating_count            INT,

    created_at              TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMP NOT NULL DEFAULT NOW()
);

-- FK
ALTER TABLE therapist_profiles
    ADD CONSTRAINT fk_therapist_profiles_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_therapist_city        ON therapist_profiles(city);
CREATE INDEX IF NOT EXISTS idx_therapist_state       ON therapist_profiles(state);
CREATE INDEX IF NOT EXISTS idx_therapist_speciality  ON therapist_profiles(primary_specialization);
CREATE INDEX IF NOT EXISTS idx_therapist_rating      ON therapist_profiles(rating_avg);

------------------------------------------------------------
-- 4. PATIENTS
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS patients (
    patient_id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID UNIQUE NOT NULL,

    full_name           VARCHAR(255) NOT NULL,
    gender              VARCHAR(20),
    date_of_birth       DATE,

    email               VARCHAR(255),
    phone               VARCHAR(20),

    city                VARCHAR(100),
    state               VARCHAR(100),
    country             VARCHAR(100),

    preferred_language  VARCHAR(100),
    preferred_mode      VARCHAR(50),        -- 'online','in_person','hybrid'
    risk_level          VARCHAR(20),        -- 'low','medium','high'
    is_suicidal_risk    BOOLEAN DEFAULT FALSE,

    referred_by_doctor  UUID,              -- FK to doctor_profiles
    referral_session_id VARCHAR(100),

    created_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

-- FKs
ALTER TABLE patients
    ADD CONSTRAINT fk_patients_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE patients
    ADD CONSTRAINT fk_patients_referred_doctor
    FOREIGN KEY (referred_by_doctor) REFERENCES doctor_profiles(id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_patients_user_id      ON patients(user_id);
CREATE INDEX IF NOT EXISTS idx_patients_city         ON patients(city);
CREATE INDEX IF NOT EXISTS idx_patients_state        ON patients(state);
CREATE INDEX IF NOT EXISTS idx_patients_risk_level   ON patients(risk_level);

------------------------------------------------------------
-- 5. DOCTOR REFERRALS
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS doctor_referrals (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doctor_id       UUID REFERENCES doctor_profiles(id) ON DELETE SET NULL,
    doctor_code     VARCHAR(20),                   -- Denormalized for faster queries
    
    -- Session tracking
    session_id      VARCHAR(100) NOT NULL,          -- Unique session for attribution
    
    -- Scan event
    scan_timestamp  TIMESTAMP DEFAULT NOW(),
    device_type     VARCHAR(50),                   -- mobile, tablet, desktop
    device_os       VARCHAR(50),                     -- iOS, Android, Windows
    browser         VARCHAR(50),
    ip_address      VARCHAR(50),
    city            VARCHAR(100),
    state           VARCHAR(50),
    country         VARCHAR(10) DEFAULT 'IN',
    user_agent      TEXT,

    -- Funnel progression
    landing_page_viewed_at  TIMESTAMP,
    signup_started_at       TIMESTAMP,
    signup_completed_at     TIMESTAMP,
    assessment_completed_at TIMESTAMP,
    subscription_started_at TIMESTAMP,

    -- Patient (after signup)
    patient_id      UUID REFERENCES patients(patient_id) ON DELETE SET NULL,

    -- Status
    status          VARCHAR(30) DEFAULT 'scanned'
        CHECK (status IN ('scanned', 'landed', 'signup_started', 'signed_up', 'assessment_done', 'subscribed', 'churned', 'expired')),

    -- Subscription details (if converted)
    subscription_tier       VARCHAR(20),             -- free, tier2, tier3
    subscription_amount     DECIMAL(10,2),
    subscription_start_date DATE,

    -- Lifetime value tracking
    lifetime_value          DECIMAL(10,2) DEFAULT 0,
    months_active           INT DEFAULT 0,

    -- Attribution window
    attribution_expires_at  TIMESTAMP,          -- 30 days from scan

    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- FK
ALTER TABLE doctor_referrals
    ADD CONSTRAINT fk_doctor_referrals_doctor
    FOREIGN KEY (doctor_id) REFERENCES doctor_profiles(id) ON DELETE CASCADE;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_doctor_referrals_doctor_id ON doctor_referrals(doctor_id);
CREATE INDEX IF NOT EXISTS idx_doctor_referrals_status    ON doctor_referrals(status);

------------------------------------------------------------
-- 6. ASSESSMENTS
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS assessments (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id          UUID NOT NULL,
    therapist_id        UUID,                       -- nullable for self-assessment

    assessment_type     VARCHAR(50) NOT NULL,       -- 'phq9','gad7',...
    responses           JSONB,                      -- raw answers
    phq9_score          INT,
    gad7_score          INT,
    phq9_severity       VARCHAR(50),
    gad7_severity       VARCHAR(50),

    administered_by     UUID,                       -- user_id (admin/therapist)
    administered_at     TIMESTAMP,
    source              VARCHAR(50),                -- 'web','mobile','kiosk','referral'
    referral_id         UUID,                       -- could link to doctor_referrals.id

    created_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

-- FKs
ALTER TABLE assessments
    ADD CONSTRAINT fk_assessments_patient
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE;

ALTER TABLE assessments
    ADD CONSTRAINT fk_assessments_therapist
    FOREIGN KEY (therapist_id) REFERENCES therapist_profiles(id);

ALTER TABLE assessments
    ADD CONSTRAINT fk_assessments_referral
    FOREIGN KEY (referral_id) REFERENCES doctor_referrals(id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_assessments_patient      ON assessments(patient_id);
CREATE INDEX IF NOT EXISTS idx_assessments_therapist    ON assessments(therapist_id);
CREATE INDEX IF NOT EXISTS idx_assessments_type         ON assessments(assessment_type);
CREATE INDEX IF NOT EXISTS idx_assessments_created_at   ON assessments(created_at);

------------------------------------------------------------
-- 7. SESSIONS
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sessions (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id          UUID NOT NULL,
    therapist_id        UUID NOT NULL,

    session_type        VARCHAR(50) NOT NULL,        -- 'therapy','assessment', etc.
    mode                VARCHAR(20) NOT NULL,        -- 'online','in_person'

    scheduled_start_at  TIMESTAMP,
    scheduled_end_at    TIMESTAMP,
    actual_start_at     TIMESTAMP,
    actual_end_at       TIMESTAMP,

    status              VARCHAR(20) NOT NULL,        -- 'scheduled','completed','cancelled'
    cancellation_reason TEXT,

    notes_internal      TEXT,
    notes_for_patient   TEXT,

    meeting_url         VARCHAR(255),
    recording_url       VARCHAR(255),

    fee_inr             NUMERIC,
    discount_inr        NUMERIC,
    amount_collected_inr NUMERIC,
    payment_status      VARCHAR(20),                 -- 'pending','paid','failed'

    created_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

-- FKs
ALTER TABLE sessions
    ADD CONSTRAINT fk_sessions_patient
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE;

ALTER TABLE sessions
    ADD CONSTRAINT fk_sessions_therapist
    FOREIGN KEY (therapist_id) REFERENCES therapist_profiles(id) ON DELETE CASCADE;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sessions_patient       ON sessions(patient_id);
CREATE INDEX IF NOT EXISTS idx_sessions_therapist     ON sessions(therapist_id);
CREATE INDEX IF NOT EXISTS idx_sessions_status        ON sessions(status);
CREATE INDEX IF NOT EXISTS idx_sessions_scheduled_at  ON sessions(scheduled_start_at);

------------------------------------------------------------
-- 8. CBT SESSION DATA
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cbt_session_data (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id          UUID NOT NULL,

    activity_type       VARCHAR(100) NOT NULL,      -- 'thought_record','behavioural_activation',...
    step_number         INT NOT NULL,
    prompt_title        VARCHAR(255),
    client_input        TEXT,
    therapist_notes     TEXT,
    ai_summary          TEXT,

    raw_payload         JSONB,
    homework_assigned   JSONB,
    homework_completed  BOOLEAN DEFAULT FALSE,

    mood_before         SMALLINT,
    mood_after          SMALLINT,

    created_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

-- FK
ALTER TABLE cbt_session_data
    ADD CONSTRAINT fk_cbt_session_data_session
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_cbt_session_session_id  ON cbt_session_data(session_id);
CREATE INDEX IF NOT EXISTS idx_cbt_session_activity    ON cbt_session_data(activity_type);

------------------------------------------------------------
-- 9. CERTIFICATES
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS certificates (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id          UUID NOT NULL,
    therapist_id        UUID NOT NULL,

    certificate_type    VARCHAR(100) NOT NULL,      -- 'cbt_program_completion',...
    program_name        VARCHAR(255),
    program_id          UUID,

    issued_at           TIMESTAMP NOT NULL,
    valid_until         TIMESTAMP,

    certificate_number  VARCHAR(100) UNIQUE,
    file_url            VARCHAR(500),

    signed_by_name      VARCHAR(255),
    signed_by_title     VARCHAR(255),

    created_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

-- FKs
ALTER TABLE certificates
    ADD CONSTRAINT fk_certificates_patient
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE;

ALTER TABLE certificates
    ADD CONSTRAINT fk_certificates_therapist
    FOREIGN KEY (therapist_id) REFERENCES therapist_profiles(id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_certificates_patient   ON certificates(patient_id);
CREATE INDEX IF NOT EXISTS idx_certificates_therapist ON certificates(therapist_id);
CREATE INDEX IF NOT EXISTS idx_certificates_issued_at ON certificates(issued_at);

------------------------------------------------------------
-- 10. LEADS
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS leads (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    assessment_id   UUID NOT NULL,
    patient_id      UUID NOT NULL,
    therapist_id    UUID NOT NULL,

    match_score     NUMERIC,
    lead_tier       VARCHAR(50),         -- 'tier1','tier2',...
    status          VARCHAR(50),         -- 'open','converted','lost',...
    source          VARCHAR(50),         -- 'assessment_quiz','landing_page',...
    notes           TEXT,

    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- FKs
ALTER TABLE leads
    ADD CONSTRAINT fk_leads_assessment
    FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE CASCADE;

ALTER TABLE leads
    ADD CONSTRAINT fk_leads_patient
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE;

ALTER TABLE leads
    ADD CONSTRAINT fk_leads_therapist
    FOREIGN KEY (therapist_id) REFERENCES therapist_profiles(id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_leads_patient         ON leads(patient_id);
CREATE INDEX IF NOT EXISTS idx_leads_therapist       ON leads(therapist_id);
CREATE INDEX IF NOT EXISTS idx_leads_status          ON leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_match_score     ON leads(match_score);

------------------------------------------------------------
-- 11. TRANSACTIONS
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transactions (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 UUID NOT NULL,
    patient_id              UUID,
    therapist_id            UUID,

    amount_inr              NUMERIC NOT NULL,
    currency                VARCHAR(10) NOT NULL DEFAULT 'INR',
    tax_inr                 NUMERIC,
    discount_inr            NUMERIC,

    payment_provider        VARCHAR(50),              -- 'razorpay','stripe',...
    provider_payment_id     VARCHAR(100),
    provider_order_id       VARCHAR(100),
    provider_signature      VARCHAR(255),

    transaction_type        VARCHAR(50),              -- 'session','subscription',...
    status                  VARCHAR(50),              -- 'pending','captured','failed',...
    session_id              UUID,
    notes                   TEXT,

    paid_at                 TIMESTAMP,
    created_at              TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMP NOT NULL DEFAULT NOW()
);

-- FKs
ALTER TABLE transactions
    ADD CONSTRAINT fk_transactions_user
    FOREIGN KEY (user_id) REFERENCES users(id);

ALTER TABLE transactions
    ADD CONSTRAINT fk_transactions_patient
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id);

ALTER TABLE transactions
    ADD CONSTRAINT fk_transactions_therapist
    FOREIGN KEY (therapist_id) REFERENCES therapist_profiles(id);

ALTER TABLE transactions
    ADD CONSTRAINT fk_transactions_session
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE SET NULL;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_transactions_user       ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_patient    ON transactions(patient_id);
CREATE INDEX IF NOT EXISTS idx_transactions_session    ON transactions(session_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status     ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at);

------------------------------------------------------------
-- 12. AUDIT LOGS
------------------------------------------------------------
-- 12. AUDIT LOGS ... (existing code omitted for brevity in replacement, but I will include it)
CREATE TABLE IF NOT EXISTS audit_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID,                   -- actor

    entity_type     VARCHAR(100) NOT NULL,  -- 'user','session','transaction',...
    entity_id       UUID,
    action          VARCHAR(100) NOT NULL,  -- 'create','update','delete','login',...
    previous_value  JSONB,
    new_value       JSONB,

    ip_address      VARCHAR(50),
    user_agent      TEXT,

    occurred_at     TIMESTAMP NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- FK
ALTER TABLE audit_logs
    ADD CONSTRAINT fk_audit_logs_user
    FOREIGN KEY (user_id) REFERENCES users(id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_user        ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity      ON audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_occurred_at ON audit_logs(occurred_at);

------------------------------------------------------------
-- 13. DOCTOR CREDITS
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS doctor_credits (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doctor_id       UUID REFERENCES doctor_profiles(id) ON DELETE CASCADE,
    referral_id     UUID REFERENCES doctor_referrals(id) ON DELETE SET NULL,
    credits         INT NOT NULL,
    credit_type     VARCHAR(30) NOT NULL
        CHECK (credit_type IN ('signup', 'assessment', 'subscription_tier2', 'subscription_tier3', 'retention_bonus', 'manual_bonus', 'manual_deduction', 'redemption')),
    base_credits    INT,
    multiplier      DECIMAL(3,2) DEFAULT 1.0,
    description     VARCHAR(255),
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_doctor_credits_doctor ON doctor_credits(doctor_id);

------------------------------------------------------------
-- 14. DOCTOR REDEMPTIONS
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS doctor_redemptions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doctor_id       UUID REFERENCES doctor_profiles(id) ON DELETE CASCADE,
    credits_redeemed INT NOT NULL,
    reward_type     VARCHAR(50) NOT NULL,
    reward_value    VARCHAR(255),
    bank_account_number VARCHAR(20),
    bank_ifsc       VARCHAR(15),
    bank_name       VARCHAR(100),
    account_holder_name VARCHAR(255),
    status          VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
    processed_at    TIMESTAMP,
    processed_by    UUID REFERENCES users(id),
    failure_reason  TEXT,
    external_reference VARCHAR(255),
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_doctor_redemptions_doctor ON doctor_redemptions(doctor_id);

------------------------------------------------------------
-- 15. DOCTOR ASSET ORDERS
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS doctor_asset_orders (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doctor_id       UUID REFERENCES doctor_profiles(id) ON DELETE CASCADE,
    order_number    VARCHAR(20) UNIQUE,
    items           JSONB NOT NULL,
    total_amount    DECIMAL(10,2),
    shipping_name   VARCHAR(255),
    shipping_address TEXT,
    shipping_city   VARCHAR(100),
    shipping_state  VARCHAR(50),
    shipping_pincode VARCHAR(10),
    shipping_phone  VARCHAR(20),
    payment_status  VARCHAR(20) DEFAULT 'pending'
        CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded')),
    payment_id      VARCHAR(100),
    paid_at         TIMESTAMP,
    fulfillment_status VARCHAR(20) DEFAULT 'pending'
        CHECK (fulfillment_status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled')),
    shipped_at      TIMESTAMP,
    tracking_number VARCHAR(100),
    tracking_url    VARCHAR(500),
    delivered_at    TIMESTAMP,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_doctor_asset_orders_doctor ON doctor_asset_orders(doctor_id);

------------------------------------------------------------
-- 16. ANALYTICS (DIM_CAMPAIGNS & FACT_QR_TRACKING)
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_campaigns (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_name   VARCHAR(255) NOT NULL,
    campaign_type   VARCHAR(50),
    start_date      DATE,
    end_date        DATE,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fact_qr_tracking (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_id     UUID REFERENCES dim_campaigns(id),
    doctor_id       UUID REFERENCES doctor_profiles(id),
    doctor_code     VARCHAR(20),
    is_doctor_referral BOOLEAN DEFAULT FALSE,
    scan_timestamp  TIMESTAMP DEFAULT NOW(),
    city            VARCHAR(100),
    state           VARCHAR(50),
    device_type     VARCHAR(50),
    created_at      TIMESTAMP DEFAULT NOW()
);

------------------------------------------------------------
-- VIEWS
------------------------------------------------------------
CREATE OR REPLACE VIEW v_doctor_dashboard AS
SELECT  
    dp.id AS doctor_id,
    dp.doctor_code,
    dp.full_name,
    dp.referral_tier,
    COUNT(dr.id) AS total_referrals,
    COUNT(CASE WHEN dr.scan_timestamp >= DATE_TRUNC('month', NOW()) THEN 1 END) AS this_month_referrals,
    COUNT(CASE WHEN dr.status IN ('signed_up', 'assessment_done', 'subscribed') THEN 1 END) AS total_signups,
    COUNT(CASE WHEN dr.status = 'subscribed' THEN 1 END) AS total_subscriptions,
    ROUND(COUNT(CASE WHEN dr.status IN ('signed_up', 'assessment_done', 'subscribed') THEN 1 END)::DECIMAL /  NULLIF(COUNT(dr.id), 0) * 100, 2) AS conversion_rate,
    COALESCE(SUM(dr.lifetime_value), 0) AS total_patient_value,
    COALESCE((SELECT SUM(credits) FROM doctor_credits WHERE doctor_id = dp.id), 0) AS total_credits_earned,
    COALESCE((SELECT SUM(credits_redeemed) FROM doctor_redemptions WHERE doctor_id = dp.id AND status = 'completed'), 0) AS total_credits_redeemed
FROM doctor_profiles dp 
LEFT JOIN doctor_referrals dr ON dp.id = dr.doctor_id 
GROUP BY dp.id, dp.doctor_code, dp.full_name, dp.referral_tier;

CREATE OR REPLACE VIEW v_doctor_credit_balance AS
SELECT  
    dp.id AS doctor_id,
    dp.doctor_code,
    dp.full_name,
    COALESCE(SUM(dc.credits), 0) AS credits_earned,
    COALESCE((SELECT SUM(credits_redeemed) FROM doctor_redemptions WHERE doctor_id = dp.id AND status IN ('completed', 'processing')), 0) AS credits_used,
    COALESCE(SUM(dc.credits), 0) - COALESCE((SELECT SUM(credits_redeemed) FROM doctor_redemptions WHERE doctor_id = dp.id AND status IN ('completed', 'processing')), 0) AS credits_available
FROM doctor_profiles dp 
LEFT JOIN doctor_credits dc ON dp.id = dc.doctor_id 
GROUP BY dp.id, dp.doctor_code, dp.full_name;

------------------------------------------------------------
-- PROCEDURAL LOGIC (FUNCTIONS & TRIGGERS)
------------------------------------------------------------

-- Generate unique doctor code
CREATE OR REPLACE FUNCTION generate_doctor_code(p_state VARCHAR) 
RETURNS VARCHAR AS $$
DECLARE 
    state_code VARCHAR(2);
    next_num INT;
    new_code VARCHAR(20);
BEGIN
    state_code := CASE p_state 
        WHEN 'Karnataka' THEN 'KA' WHEN 'Maharashtra' THEN 'MH' WHEN 'Delhi' THEN 'DL' 
        WHEN 'Tamil Nadu' THEN 'TN' WHEN 'Telangana' THEN 'TS' WHEN 'Kerala' THEN 'KL' 
        WHEN 'Gujarat' THEN 'GJ' WHEN 'West Bengal' THEN 'WB' WHEN 'Uttar Pradesh' THEN 'UP' 
        WHEN 'Rajasthan' THEN 'RJ' ELSE 'XX' 
    END;
    SELECT COALESCE(MAX(CAST(SUBSTRING(doctor_code FROM 'DR-' || state_code || '-(\d+)') AS INT)), 0) + 1
    INTO next_num FROM doctor_profiles WHERE doctor_code LIKE 'DR-' || state_code || '-%';
    new_code := 'DR-' || state_code || '-' || LPAD(next_num::TEXT, 4, '0');
    RETURN new_code;
END;
$$ LANGUAGE plpgsql;

-- Award credits to doctor
CREATE OR REPLACE FUNCTION award_doctor_credits(p_doctor_id UUID, p_referral_id UUID, p_credit_type VARCHAR, p_base_credits INT, p_description VARCHAR DEFAULT NULL) 
RETURNS INT AS $$
DECLARE 
    v_multiplier DECIMAL(3,2);
    v_final_credits INT;
BEGIN
    SELECT CASE referral_tier WHEN 'bronze' THEN 1.0 WHEN 'silver' THEN 1.25 WHEN 'gold' THEN 1.5 WHEN 'platinum' THEN 2.0 ELSE 1.0 END INTO v_multiplier
    FROM doctor_profiles WHERE id = p_doctor_id;
    v_final_credits := ROUND(p_base_credits * v_multiplier);
    INSERT INTO doctor_credits (doctor_id, referral_id, credits, credit_type, base_credits, multiplier, description) 
    VALUES (p_doctor_id, p_referral_id, v_final_credits, p_credit_type, p_base_credits, v_multiplier, p_description);
    PERFORM check_doctor_tier_upgrade(p_doctor_id);
    RETURN v_final_credits;
END;
$$ LANGUAGE plpgsql;

-- Check and upgrade doctor tier
CREATE OR REPLACE FUNCTION check_doctor_tier_upgrade(p_doctor_id UUID) 
RETURNS VOID AS $$
DECLARE 
    v_total_referrals INT;
    v_current_tier VARCHAR(20);
    v_new_tier VARCHAR(20);
BEGIN
    SELECT COUNT(*) INTO v_total_referrals FROM doctor_referrals WHERE doctor_id = p_doctor_id AND status IN ('signed_up', 'assessment_done', 'subscribed');
    SELECT referral_tier INTO v_current_tier FROM doctor_profiles WHERE id = p_doctor_id;
    v_new_tier := CASE WHEN v_total_referrals >= 100 THEN 'platinum' WHEN v_total_referrals >= 50 THEN 'gold' WHEN v_total_referrals >= 25 THEN 'silver' ELSE 'bronze' END;
    IF v_new_tier != v_current_tier THEN UPDATE doctor_profiles SET referral_tier = v_new_tier, updated_at = NOW() WHERE id = p_doctor_id; END IF;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update timestamp
CREATE OR REPLACE FUNCTION update_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_doctor_redemptions_updated BEFORE UPDATE ON doctor_redemptions FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tr_doctor_asset_orders_updated BEFORE UPDATE ON doctor_asset_orders FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- RLS POLICIES
ALTER TABLE doctor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE doctor_referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE doctor_credits ENABLE ROW LEVEL SECURITY;
ALTER TABLE doctor_redemptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Doctors see own profile" ON doctor_profiles FOR SELECT USING (user_id = (SELECT id FROM users WHERE id = user_id));
CREATE POLICY "Admins see all profiles" ON doctor_profiles FOR ALL USING (EXISTS (SELECT 1 FROM users WHERE role = 'admin'));
