 
SET SERVEROUTPUT ON;
 
ALTER SESSION SET "_ORACLE_SCRIPT"=TRUE;

/// a sql statements to create a user to manage the Hospital database by sysdba 
--create user Hospital_dba 
--identified by 12345;
--
--
--grant create session to Hospital_dba;



--- script to create tables 

-- Patients Table
CREATE TABLE Patients (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    date_of_birth DATE NOT NULL,
    status VARCHAR2(50) NOT NULL, -- Admitted, Discharged, etc.
    total_bill NUMBER(10, 2) DEFAULT 0,
    room_type VARCHAR2(50) NOT NULL, -- Type of room requested
    room_id NUMBER, -- ID of the assigned room
    CONSTRAINT fk_room FOREIGN KEY (room_id) REFERENCES Rooms(id) -- Foreign key for room
);

-- Doctors Table
CREATE TABLE Doctors (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    specialty VARCHAR2(100) NOT NULL,
    available_hours VARCHAR2(100) -- Available hours in a readable format ('9AM-5PM')
);

-- Appointments Table
CREATE TABLE Appointments (
    id NUMBER PRIMARY KEY,
    patient_id NUMBER NOT NULL,
    doctor_id NUMBER NOT NULL,
    appointment_date DATE NOT NULL,
    status VARCHAR2(50) NOT NULL, -- Scheduled, Completed, Canceled
    CONSTRAINT fk_patient FOREIGN KEY (patient_id) REFERENCES Patients (id),
    CONSTRAINT fk_doctor FOREIGN KEY (doctor_id) REFERENCES Doctors (id)
);

-- Treatments Table
CREATE TABLE Treatments (
    id NUMBER PRIMARY KEY,
    patient_id NUMBER NOT NULL,
    doctor_id NUMBER NOT NULL,
    treatment_description VARCHAR2(255) NOT NULL,
    cost NUMBER(10, 2) NOT NULL,
    CONSTRAINT fk_patient_treatment FOREIGN KEY (patient_id) REFERENCES Patients (id),
    CONSTRAINT fk_doctor_treatment FOREIGN KEY (doctor_id) REFERENCES Doctors (id)
);

-- Rooms Table
CREATE TABLE Rooms (
    id NUMBER PRIMARY KEY,
    type VARCHAR2(50) NOT NULL, -- Room type (Single, Double)
    capacity NUMBER NOT NULL, -- Number of beds in the room
    availability boolean NOT NULL -- Available, Occupied, etc. (status)
);


-- AuditTrail Table
CREATE TABLE AuditTrail (
    id NUMBER PRIMARY KEY,
    table_name VARCHAR2(100) NOT NULL,
    operation VARCHAR2(50) NOT NULL, -- INSERT, UPDATE, DELETE
    old_data CLOB, -- Store old data in JSON format or as text
    new_data CLOB, -- Store new data in JSON format or as text
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Warnings Table
CREATE TABLE Warnings (
    id NUMBER PRIMARY KEY,
    patient_id NUMBER NOT NULL,
    warning_reason VARCHAR2(255) NOT NULL, -- Reason for the warning
    warning_date DATE NOT NULL,
    CONSTRAINT fk_patient_warning FOREIGN KEY (patient_id) REFERENCES Patients (id)
);

/* SEQUENCES DEFINITION FOR ID ASSIGNMENT */

CREATE SEQUENCE patient_seq
START WITH 1
INCREMENT BY 1;

CREATE SEQUENCE doctor_seq
START WITH 1
INCREMENT BY 1;

CREATE SEQUENCE appointment_seq
START WITH 1
INCREMENT BY 1;

CREATE SEQUENCE treatment_seq
START WITH 1
INCREMENT BY 1;

CREATE SEQUENCE room_seq
START WITH 1
INCREMENT BY 1;

CREATE SEQUENCE audit_seq
START WITH 1
INCREMENT BY 1;

CREATE SEQUENCE warning_seq
START WITH 1
INCREMENT BY 1;




---- Features Implementation 
-- 1.Patient Admission Validation
/*
    THE BREAK DOWN OF THE TALBES INCLUDED IN THIS TRIGGER 
    1. ROOMS
    2. PATIENTS
    3. AUDITTRAIL
    TRIGER WILL WORK BEFORE AN INSERT OPERATION 
    ON EASH ROW ON PATIENT TABLE
**/

CREATE OR REPLACE TRIGGER patient_validation_trg
BEFORE INSERT ON PATIENTS 
FOR EACH ROW 
DECLARE 
    assigned_room_id NUMBER;
BEGIN 
    -- 1: check for an available room of the requested type
    -- Use SELECT INTO and handle NO_DATA_FOUND exception
    BEGIN
        SELECT MIN(id) INTO assigned_room_id
        FROM Rooms
        WHERE type = :NEW.room_type 
              AND availability = TRUE;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- 2: raise an error if no rooms are available
            RAISE_APPLICATION_ERROR(-20001, 'No rooms of the requested type are available.');
    END;

    -- 3: Assign the room to the patient
    :NEW.room_id := assigned_room_id;

    -- 4: Update room availability (set to FALSE since the room is now occupied)
    UPDATE Rooms
    SET availability = FALSE
    WHERE id = assigned_room_id;

    -- 5: Log the operation in the AuditTrail table
    INSERT INTO AuditTrail (id, table_name, operation, old_data, new_data, timestamp)
    VALUES (
        audit_seq.NEXTVAL, -- Assuming an auto-increment sequence for AuditTrail
        'Patients',
        'INSERT',
        NULL, -- Old data is null since it's an insert operation 
        'Assigned Room ID: ' || assigned_room_id || ' to Patient ID: ' || :NEW.id,
        SYSTIMESTAMP
    );
END;

--- test data to test trigger

INSERT INTO Rooms (id, type, capacity, availability) 
VALUES (room_seq.NEXTVAL, 'Single', 1, TRUE); -- Available room
INSERT INTO Rooms (id, type, capacity, availability) 
VALUES (room_seq.NEXTVAL, 'Single', 1, TRUE); -- Available room
INSERT INTO Rooms (id, type, capacity, availability) 
VALUES (room_seq.NEXTVAL, 'Double', 2, FALSE); -- Occupied room

INSERT INTO Patients (id, name, date_of_birth, status, room_type) 
VALUES (patient_seq.NEXTVAL, 'John Doe', TO_DATE('1990-01-01', 'YYYY-MM-DD'), 'Admitted', 'Single');

