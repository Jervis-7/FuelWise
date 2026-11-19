CREATE DATABASE IF NOT EXISTS fuelwise CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE fuelwise;
CREATE TABLE IF NOT EXISTS users (
 id INT AUTO_INCREMENT PRIMARY KEY, full_name VARCHAR(120) NOT NULL, email VARCHAR(190) NOT NULL UNIQUE,
 password_hash VARCHAR(255) NOT NULL, role ENUM('Admin','Manager','Staff') NOT NULL DEFAULT 'Staff',
 is_active TINYINT(1) NOT NULL DEFAULT 1, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS vehicles (
 id INT AUTO_INCREMENT PRIMARY KEY, plate_no VARCHAR(30) NOT NULL UNIQUE, vehicle_name VARCHAR(100) NOT NULL,
 vehicle_type ENUM('Truck','Van','Car','Motorcycle','Other') NOT NULL, fuel_type ENUM('Diesel','Gasoline') NOT NULL,
 is_active TINYINT(1) NOT NULL DEFAULT 1, created_by INT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY(created_by) REFERENCES users(id) ON DELETE SET NULL
);
CREATE TABLE IF NOT EXISTS fuel_transactions (
 id BIGINT AUTO_INCREMENT PRIMARY KEY, vehicle_id INT NOT NULL, transaction_date DATE NOT NULL,
 fuel_type ENUM('Diesel','Gasoline') NOT NULL, liters DECIMAL(12,2) NOT NULL, price_per_liter DECIMAL(12,2) NOT NULL,
 total_cost DECIMAL(14,2) GENERATED ALWAYS AS (ROUND(liters * price_per_liter,2)) STORED,
 odometer_km DECIMAL(14,2) NULL, reference_no VARCHAR(100) NULL, notes TEXT NULL, recorded_by INT NULL,
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, INDEX idx_tx_date(transaction_date), INDEX idx_tx_vehicle(vehicle_id),
 FOREIGN KEY(vehicle_id) REFERENCES vehicles(id), FOREIGN KEY(recorded_by) REFERENCES users(id) ON DELETE SET NULL
);
CREATE TABLE IF NOT EXISTS saved_scenarios (
 id INT AUTO_INCREMENT PRIMARY KEY, scenario_name VARCHAR(120) NOT NULL, current_price DECIMAL(12,2) NOT NULL,
 scenario_price DECIMAL(12,2) NOT NULL, monthly_liters DECIMAL(12,2) NOT NULL, created_by INT NULL,
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(created_by) REFERENCES users(id) ON DELETE SET NULL
);
CREATE TABLE IF NOT EXISTS report_exports (
 id BIGINT AUTO_INCREMENT PRIMARY KEY, report_name VARCHAR(150) NOT NULL, period_label VARCHAR(100) NOT NULL,
 file_format ENUM('CSV','PDF','Excel') NOT NULL DEFAULT 'CSV', generated_by INT NULL,
 generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(generated_by) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS fuel_types (
 id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 name VARCHAR(60) NOT NULL UNIQUE,
 is_active BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;
INSERT INTO fuel_types(name) VALUES ('Diesel'),('Gasoline') ON DUPLICATE KEY UPDATE name=VALUES(name);
CREATE TABLE IF NOT EXISTS audit_logs (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, user_id INT NULL,
 action VARCHAR(80) NOT NULL, entity_type VARCHAR(80) NULL, entity_id BIGINT UNSIGNED NULL,
 details_json JSON NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE SET NULL,
 INDEX idx_audit_created_at(created_at), INDEX idx_audit_entity(entity_type,entity_id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS system_settings (
 setting_key VARCHAR(100) PRIMARY KEY, setting_value TEXT NOT NULL, updated_by INT NULL,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 FOREIGN KEY(updated_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;
CREATE OR REPLACE VIEW vw_monthly_fuel_summary AS
 SELECT DATE_FORMAT(transaction_date,'%Y-%m') month, SUM(liters) total_liters,
 SUM(total_cost) total_expense,
 ROUND(SUM(total_cost)/NULLIF(SUM(liters),0),4) weighted_avg_price_per_liter,
 COUNT(*) transaction_count
 FROM fuel_transactions GROUP BY DATE_FORMAT(transaction_date,'%Y-%m');

ALTER TABLE users MODIFY full_name VARCHAR(150) NOT NULL, ADD COLUMN username VARCHAR(80) NULL UNIQUE;
ALTER TABLE vehicles MODIFY vehicle_name VARCHAR(120) NOT NULL;
ALTER TABLE fuel_transactions MODIFY liters DECIMAL(12,3) NOT NULL,
 MODIFY price_per_liter DECIMAL(12,4) NOT NULL,
 MODIFY total_cost DECIMAL(16,2) GENERATED ALWAYS AS (ROUND(liters * price_per_liter,2)) STORED,
 ADD INDEX idx_transactions_vehicle_date(vehicle_id,transaction_date),
 ADD INDEX idx_transactions_fuel_date(fuel_type,transaction_date),
 ADD CONSTRAINT chk_liters_positive CHECK(liters>0),
 ADD CONSTRAINT chk_price_nonnegative CHECK(price_per_liter>=0),
 ADD CONSTRAINT chk_odometer_nonnegative CHECK(odometer_km IS NULL OR odometer_km>=0);
ALTER TABLE report_exports
 ADD COLUMN report_type ENUM('fuel_expense','fuel_consumption','vehicle_performance','forecast','scenario_analysis') NULL,
 ADD COLUMN date_from DATE NULL, ADD COLUMN date_to DATE NULL,
 ADD COLUMN vehicle_id INT NULL, ADD COLUMN fuel_type_id SMALLINT UNSIGNED NULL,
 ADD COLUMN parameters_json JSON NULL, ADD COLUMN file_name VARCHAR(255) NULL,
 ADD CONSTRAINT fk_report_vehicle FOREIGN KEY(vehicle_id) REFERENCES vehicles(id) ON DELETE SET NULL,
 ADD CONSTRAINT fk_report_fuel FOREIGN KEY(fuel_type_id) REFERENCES fuel_types(id) ON DELETE SET NULL,
 ADD CONSTRAINT chk_report_dates CHECK(date_from IS NULL OR date_to IS NULL OR date_from<=date_to),
 ADD INDEX idx_report_generated_at(generated_at);

CREATE TABLE IF NOT EXISTS schema_migrations(version VARCHAR(80) PRIMARY KEY, applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
INSERT INTO schema_migrations(version) VALUES('001-ui-support');
