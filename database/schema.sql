-- =============================================================================
-- INTERNATIONAL ENTERPRISE CRM & GLOBAL BUSINESS INTELLIGENCE PLATFORM
-- Normalized PostgreSQL Relational Schema (27 Core Tables + Audit & Security)
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. ROLES
CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY,
    role_code VARCHAR(50) UNIQUE NOT NULL,
    role_name VARCHAR(100) NOT NULL,
    description TEXT,
    is_system_role BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2. PERMISSIONS
CREATE TABLE permissions (
    permission_id SERIAL PRIMARY KEY,
    permission_key VARCHAR(100) UNIQUE NOT NULL,
    module_name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Role-Permission Mapping
CREATE TABLE role_permissions (
    role_id INTEGER NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
    permission_id INTEGER NOT NULL REFERENCES permissions(permission_id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- 3. USERS
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(80) UNIQUE NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role_id INTEGER NOT NULL REFERENCES roles(role_id),
    designation VARCHAR(100),
    department VARCHAR(100),
    phone VARCHAR(50),
    timezone VARCHAR(64) DEFAULT 'UTC',
    preferred_currency VARCHAR(10) DEFAULT 'USD',
    mfa_enabled BOOLEAN DEFAULT FALSE,
    mfa_secret VARCHAR(128),
    is_active BOOLEAN DEFAULT TRUE,
    is_locked BOOLEAN DEFAULT FALSE,
    failed_login_attempts INTEGER DEFAULT 0,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 4. COUNTRIES
CREATE TABLE countries (
    country_id SERIAL PRIMARY KEY,
    iso_code CHAR(2) UNIQUE NOT NULL,
    iso3_code CHAR(3) UNIQUE NOT NULL,
    country_name VARCHAR(100) UNIQUE NOT NULL,
    region VARCHAR(80) NOT NULL,
    phone_code VARCHAR(15) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL
);

-- 5. STATES
CREATE TABLE states (
    state_id SERIAL PRIMARY KEY,
    country_id INTEGER NOT NULL REFERENCES countries(country_id) ON DELETE CASCADE,
    state_name VARCHAR(120) NOT NULL,
    state_code VARCHAR(20),
    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,
    UNIQUE (country_id, state_name)
);

-- 6. CITIES
CREATE TABLE cities (
    city_id SERIAL PRIMARY KEY,
    state_id INTEGER NOT NULL REFERENCES states(state_id) ON DELETE CASCADE,
    country_id INTEGER NOT NULL REFERENCES countries(country_id) ON DELETE CASCADE,
    city_name VARCHAR(120) NOT NULL,
    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,
    UNIQUE (state_id, city_name)
);

-- 7. INDUSTRIES (20 Default + Admin Extensible)
CREATE TABLE industries (
    industry_id SERIAL PRIMARY KEY,
    industry_code VARCHAR(40) UNIQUE NOT NULL,
    industry_name VARCHAR(120) UNIQUE NOT NULL,
    relevance_weight INTEGER DEFAULT 15,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 8. SECTORS
CREATE TABLE sectors (
    sector_id SERIAL PRIMARY KEY,
    industry_id INTEGER NOT NULL REFERENCES industries(industry_id) ON DELETE CASCADE,
    sector_name VARCHAR(120) NOT NULL,
    sub_sector_name VARCHAR(120),
    relevance_weight INTEGER DEFAULT 15,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (industry_id, sector_name)
);

-- 9. PRODUCT CATEGORIES
CREATE TABLE product_categories (
    category_id SERIAL PRIMARY KEY,
    sector_id INTEGER NOT NULL REFERENCES sectors(sector_id) ON DELETE CASCADE,
    category_name VARCHAR(150) NOT NULL,
    hs_code VARCHAR(30),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 10. LEAD SOURCES
CREATE TABLE lead_sources (
    source_id SERIAL PRIMARY KEY,
    source_name VARCHAR(100) UNIQUE NOT NULL,
    score_weight INTEGER DEFAULT 10,
    is_active BOOLEAN DEFAULT TRUE
);

-- 11. LEAD STATUSES
CREATE TABLE lead_statuses (
    status_id SERIAL PRIMARY KEY,
    status_name VARCHAR(80) UNIQUE NOT NULL,
    pipeline_stage_order INTEGER NOT NULL,
    color_hex VARCHAR(10) DEFAULT '#3B82F6',
    is_terminal BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE
);

-- 12. COMPANIES (360-Degree Profile Master)
CREATE TABLE companies (
    company_id SERIAL PRIMARY KEY,
    company_code VARCHAR(30) UNIQUE NOT NULL,
    company_name VARCHAR(200) NOT NULL,
    website VARCHAR(255),
    email VARCHAR(150),
    telephone VARCHAR(50),
    country_id INTEGER REFERENCES countries(country_id),
    state_id INTEGER REFERENCES states(state_id),
    city_id INTEGER REFERENCES cities(city_id),
    industry_id INTEGER REFERENCES industries(industry_id),
    sector_id INTEGER REFERENCES sectors(sector_id),
    annual_revenue_usd NUMERIC(15,2),
    employee_count INTEGER,
    assigned_salesperson_id INTEGER REFERENCES users(user_id),
    data_classification VARCHAR(30) NOT NULL DEFAULT 'DEMO DATA' CHECK (data_classification IN ('DEMO DATA', 'REAL BUSINESS DATA')),
    profile_completion_pct INTEGER DEFAULT 100,
    remarks TEXT,
    created_by INTEGER REFERENCES users(user_id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 13. CONTACTS
CREATE TABLE contacts (
    contact_id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
    full_name VARCHAR(150) NOT NULL,
    designation VARCHAR(120),
    email VARCHAR(150),
    telephone VARCHAR(50),
    is_primary BOOLEAN DEFAULT TRUE,
    data_classification VARCHAR(30) NOT NULL DEFAULT 'DEMO DATA',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 14. LEADS (Core 23-Attribute Lead Record + Mandatory Ownership &Incomplete Tracking)
CREATE TABLE leads (
    lead_id SERIAL PRIMARY KEY,
    lead_code VARCHAR(30) UNIQUE NOT NULL,
    company_id INTEGER REFERENCES companies(company_id) ON DELETE SET NULL,
    company_name VARCHAR(200),
    contact_person VARCHAR(150),
    designation VARCHAR(120),
    email VARCHAR(150),
    telephone VARCHAR(50),
    website VARCHAR(255),
    country_id INTEGER REFERENCES countries(country_id),
    state_id INTEGER REFERENCES states(state_id),
    city_id INTEGER REFERENCES cities(city_id),
    country_name VARCHAR(100),
    state_name VARCHAR(120),
    city_name VARCHAR(120),
    industry_id INTEGER REFERENCES industries(industry_id),
    sector_id INTEGER REFERENCES sectors(sector_id),
    category_id INTEGER REFERENCES product_categories(category_id),
    industry_name VARCHAR(120),
    sector_name VARCHAR(120),
    sub_sector_name VARCHAR(120),
    product_category VARCHAR(150),
    source_id INTEGER REFERENCES lead_sources(source_id),
    lead_source VARCHAR(100),
    status_id INTEGER REFERENCES lead_statuses(status_id),
    lead_status VARCHAR(80) NOT NULL DEFAULT 'New Lead',
    lead_priority VARCHAR(40) NOT NULL DEFAULT 'Medium Priority',
    lead_temperature VARCHAR(20) NOT NULL DEFAULT 'Warm',
    lead_score INTEGER NOT NULL DEFAULT 50 CHECK (lead_score >= 0 AND lead_score <= 100),
    estimated_deal_value_usd NUMERIC(15,2) DEFAULT 0,
    lead_owner_id INTEGER NOT NULL REFERENCES users(user_id),
    assigned_salesperson_id INTEGER NOT NULL REFERENCES users(user_id),
    previous_salesperson_id INTEGER REFERENCES users(user_id),
    created_by INTEGER NOT NULL REFERENCES users(user_id),
    last_modified_by INTEGER NOT NULL REFERENCES users(user_id),
    followup_date DATE,
    remarks TEXT,
    is_incomplete BOOLEAN DEFAULT FALSE,
    completion_percentage INTEGER DEFAULT 100,
    missing_fields_json TEXT DEFAULT '[]',
    data_classification VARCHAR(30) NOT NULL DEFAULT 'DEMO DATA' CHECK (data_classification IN ('DEMO DATA', 'REAL BUSINESS DATA')),
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 15. FOLLOW-UPS
CREATE TABLE follow_ups (
    followup_id SERIAL PRIMARY KEY,
    lead_id INTEGER NOT NULL REFERENCES leads(lead_id) ON DELETE CASCADE,
    salesperson_id INTEGER NOT NULL REFERENCES users(user_id),
    scheduled_date DATE NOT NULL,
    scheduled_time VARCHAR(20) DEFAULT '10:00 UTC',
    channel VARCHAR(50) NOT NULL DEFAULT 'Email',
    status VARCHAR(40) NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Completed', 'Overdue', 'Escalated', 'Rescheduled')),
    priority VARCHAR(30) DEFAULT 'High',
    subject VARCHAR(200) NOT NULL,
    notes TEXT,
    outcome TEXT,
    next_followup_date DATE,
    escalated_to_manager BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 16. TASKS
CREATE TABLE tasks (
    task_id SERIAL PRIMARY KEY,
    lead_id INTEGER REFERENCES leads(lead_id) ON DELETE SET NULL,
    assigned_to INTEGER NOT NULL REFERENCES users(user_id),
    Assigned_by INTEGER NOT NULL REFERENCES users(user_id),
    title VARCHAR(200) NOT NULL,
    description TEXT,
    due_date DATE NOT NULL,
    priority VARCHAR(30) DEFAULT 'Medium',
    status VARCHAR(40) DEFAULT 'Pending' CHECK (status IN ('Pending', 'In Progress', 'Completed', 'Deferred')),
    comments TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ
);

-- 17. DOCUMENTS
CREATE TABLE documents (
    document_id SERIAL PRIMARY KEY,
    lead_id INTEGER REFERENCES leads(lead_id) ON DELETE CASCADE,
    company_id INTEGER REFERENCES companies(company_id) ON DELETE CASCADE,
    file_name VARCHAR(255) NOT NULL,
    file_type VARCHAR(20) NOT NULL CHECK (file_type IN ('PDF', 'XLSX', 'DOCX', 'JPG', 'PNG', 'CSV')),
    file_size_kb INTEGER NOT NULL,
    category VARCHAR(80) NOT NULL,
    access_level VARCHAR(50) DEFAULT 'Sales Team',
    uploaded_by INTEGER NOT NULL REFERENCES users(user_id),
    storage_path VARCHAR(500) NOT NULL,
    uploaded_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 18. ACTIVITY LOGS (Immutable Ownership, Assignment, Status & Audit Trail)
CREATE TABLE activity_logs (
    log_id SERIAL PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(50) NOT NULL,
    lead_id INTEGER REFERENCES leads(lead_id) ON DELETE SET NULL,
    action_type VARCHAR(80) NOT NULL,
    field_changed VARCHAR(100),
    previous_value TEXT,
    new_value TEXT,
    performed_by INTEGER NOT NULL REFERENCES users(user_id),
    performed_by_name VARCHAR(150) NOT NULL,
    ip_address VARCHAR(45) DEFAULT '10.24.0.15',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 19. EMAIL HISTORY
CREATE TABLE email_history (
    email_id SERIAL PRIMARY KEY,
    lead_id INTEGER NOT NULL REFERENCES leads(lead_id) ON DELETE CASCADE,
    company_id INTEGER REFERENCES companies(company_id) ON DELETE SET NULL,
    sender_user_id INTEGER NOT NULL REFERENCES users(user_id),
    recipient_email VARCHAR(150) NOT NULL,
    template_used VARCHAR(100),
    subject VARCHAR(255) NOT NULL,
    body_preview TEXT NOT NULL,
    delivery_status VARCHAR(40) DEFAULT 'Sent',
    sent_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 20. NOTIFICATIONS
CREATE TABLE notifications (
    notification_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    lead_id INTEGER REFERENCES leads(lead_id) ON DELETE CASCADE,
    notification_type VARCHAR(60) NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 21. IMPORT HISTORY
CREATE TABLE import_history (
    import_id SERIAL PRIMARY KEY,
    file_name VARCHAR(255) NOT NULL,
    template_type VARCHAR(100) NOT NULL,
    total_rows INTEGER NOT NULL,
    imported_rows INTEGER NOT NULL,
    failed_rows INTEGER NOT NULL,
    duplicate_rows INTEGER NOT NULL,
    data_classification VARCHAR(30) DEFAULT 'REAL BUSINESS DATA',
    status VARCHAR(40) NOT NULL DEFAULT 'Completed',
    error_report_json TEXT,
    imported_by INTEGER NOT NULL REFERENCES users(user_id),
    imported_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 22. EXPORT HISTORY
CREATE TABLE export_history (
    export_id SERIAL PRIMARY KEY,
    export_scope VARCHAR(120) NOT NULL,
    file_format VARCHAR(20) NOT NULL CHECK (file_format IN ('XLSX', 'CSV', 'PDF')),
    record_count INTEGER NOT NULL,
    excluded_demo_data BOOLEAN DEFAULT FALSE,
    exported_by INTEGER NOT NULL REFERENCES users(user_id),
    exported_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 23. DUPLICATE RECORDS
CREATE TABLE duplicate_records (
    duplicate_id SERIAL PRIMARY KEY,
    primary_lead_id INTEGER NOT NULL REFERENCES leads(lead_id) ON DELETE CASCADE,
    duplicate_lead_id INTEGER NOT NULL REFERENCES leads(lead_id) ON DELETE CASCADE,
    match_criteria VARCHAR(200) NOT NULL,
    similarity_score INTEGER NOT NULL,
    resolution_status VARCHAR(40) DEFAULT 'Pending Review' CHECK (resolution_status IN ('Pending Review', 'Merged', 'Dismissed')),
    resolved_by INTEGER REFERENCES users(user_id),
    resolution_notes TEXT,
    detected_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ
);

-- 24. APPROVAL REQUESTS
CREATE TABLE approval_requests (
    approval_id SERIAL PRIMARY KEY,
    request_code VARCHAR(30) UNIQUE NOT NULL,
    operation_type VARCHAR(80) NOT NULL CHECK (operation_type IN ('Bulk Lead Deletion', 'Lead Merging', 'Important Data Change', 'Large Record Export', 'Database Restoration', 'Capacity Upgrade')),
    target_summary TEXT NOT NULL,
    affected_records_count INTEGER DEFAULT 1,
    requested_by INTEGER NOT NULL REFERENCES users(user_id),
    reviewed_by INTEGER REFERENCES users(user_id),
    status VARCHAR(40) DEFAULT 'Pending Approval' CHECK (status IN ('Pending Approval', 'Approved', 'Rejected')),
    reviewer_comments TEXT,
    requested_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMPTZ
);

-- 25. CUSTOM FIELDS
CREATE TABLE custom_fields (
    field_id SERIAL PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL DEFAULT 'Lead',
    field_key VARCHAR(80) UNIQUE NOT NULL,
    field_label VARCHAR(120) NOT NULL,
    field_type VARCHAR(40) NOT NULL CHECK (field_type IN ('Text', 'Number', 'Date', 'Dropdown', 'Boolean')),
    options_json TEXT DEFAULT '[]',
    is_required BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_by INTEGER REFERENCES users(user_id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 26. SYSTEM SETTINGS (Capacity, Currency, Backup Retention, Security)
CREATE TABLE system_settings (
    setting_key VARCHAR(100) PRIMARY KEY,
    setting_value TEXT NOT NULL,
    setting_group VARCHAR(60) NOT NULL,
    description TEXT,
    updated_by INTEGER REFERENCES users(user_id),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 27. BACKUP HISTORY
CREATE TABLE backup_history (
    backup_id SERIAL PRIMARY KEY,
    backup_code VARCHAR(40) UNIQUE NOT NULL,
    backup_type VARCHAR(40) NOT NULL CHECK (backup_type IN ('Automated Daily', 'Automated Weekly', 'Automated Monthly', 'Manual Snapshot', 'Pre-Restoration Safety Backup', 'Pre-Demo-Purge Backup')),
    storage_location VARCHAR(255) NOT NULL,
    file_size_kb INTEGER NOT NULL,
    records_snapshot_count INTEGER NOT NULL,
    sha256_checksum VARCHAR(64) NOT NULL,
    verification_status VARCHAR(40) NOT NULL DEFAULT 'Verified OK',
    retention_policy VARCHAR(60) NOT NULL DEFAULT '30 Days',
    created_by INTEGER REFERENCES users(user_id),
    restored_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- PERFORMANCE INDEXES (Scalable to 5,000+ Records without Redesign)
-- =============================================================================
CREATE INDEX idx_leads_country ON leads(country_id, state_id, city_id);
CREATE INDEX idx_leads_industry_sector ON leads(industry_id, sector_id);
CREATE INDEX idx_leads_status_priority ON leads(lead_status, lead_priority);
CREATE INDEX idx_leads_salesperson ON leads(assigned_salesperson_id);
CREATE INDEX idx_leads_classification ON leads(data_classification);
CREATE INDEX idx_leads_incomplete ON leads(is_incomplete);
CREATE INDEX idx_leads_followup ON leads(followup_date);
CREATE INDEX idx_activity_logs_lead ON activity_logs(lead_id, created_at DESC);
CREATE INDEX idx_followups_sched ON follow_ups(scheduled_date, status);
CREATE INDEX idx_companies_name_email ON companies(company_name, email);
