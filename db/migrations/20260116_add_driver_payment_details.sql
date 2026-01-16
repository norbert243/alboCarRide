CREATE TABLE driver_payment_details (
    id UUID PRIMARY KEY REFERENCES drivers(id) ON DELETE CASCADE,
    bank_name VARCHAR(255),
    account_number VARCHAR(100),
    branch_code VARCHAR(100),
    mobile_money_number VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TRIGGER update_driver_payment_details_updated_at BEFORE UPDATE ON driver_payment_details
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
