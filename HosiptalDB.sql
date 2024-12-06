SET SERVEROUTPUT ON; 
ALTER SESSION SET "_ORACLE_SCRIPT"=TRUE

-- a sql statements to create a user to manage the Hospital database by sysdba 
create user Hospital_dba
identified by 12345;

-- granting privs
grant create table,
     create procedure, 
     create trigger,
     create sequence,
     create user, 
     update user,
     drop user 
     to hospital_dba with admin option;
     
-- alter quota 
ALTER USER hospital_dba QUOTA 100M ON USERS;

--- create two users as a feature 9 
CREATE USER user1 IDENTIFIED BY 123;
CREATE USER user2 IDENTIFIED BY 456;
grant create table,create session to user1;
grant create session to user2;
-- after any insertion in any table of anoher user must coomit to avoid the case of blocker waiting 

--- script to create tables 
-- Patients Table is been created from user1 
-- use it as user1.patients


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

-- is been create by user, so we'll use it as user1.Rooms
-- Rooms Table
CREATE TABLE Rooms (
    id NUMBER PRIMARY KEY,
    type VARCHAR2(50) NOT NULL, -- Room type (Single, Double)
    capacity NUMBER NOT NULL, -- Number of beds in the room
    availability boolean NOT NULL -- Available, Occupied, etc. (status)
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
    CONSTRAINT fk_patient FOREIGN KEY (patient_id) REFERENCES user1.Patients (id),
    CONSTRAINT fk_doctor FOREIGN KEY (doctor_id) REFERENCES Doctors (id)
);

-- Treatments Table
CREATE TABLE Treatments (
    id NUMBER PRIMARY KEY,
    patient_id NUMBER NOT NULL,
    doctor_id NUMBER NOT NULL,
    treatment_description VARCHAR2(255) NOT NULL,
    cost NUMBER(10, 2) NOT NULL,
    CONSTRAINT fk_patient_treatment FOREIGN KEY (patient_id) REFERENCES user1.Patients (id),
    CONSTRAINT fk_doctor_treatment FOREIGN KEY (doctor_id) REFERENCES Doctors (id)
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
    CONSTRAINT fk_patient_warning FOREIGN KEY (patient_id) REFERENCES user1.Patients (id)
);

/*  SEQUENCES DEFINITION FOR ID ASSIGNMENT, created by hospital_dba */
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

--- Grant insert privs for user2 and hospital_dba on patients and romms 
grant insert on patients to user2;
grant insert on rooms to user2;
grant all on Patients to hospital_dba;
grant all on rooms to hospital_dba;

--- Inserting data into tables by user2 and using seqs of hospital_dba
-- insert 5 row in each table by user2
INSERT INTO USER1.Rooms (id, type, capacity, availability) 
VALUES (hospital_dba.room_seq.NEXTVAL, 'Single', 1, TRUE); -- Available room
INSERT INTO USER1.Rooms (id, type, capacity, availability) 
VALUES(hospital_dba.room_seq.NEXTVAL, 'Single', 1, TRUE); -- Available room
INSERT INTO USER1.Rooms (id, type, capacity, availability) 
VALUES(hospital_dba.room_seq.NEXTVAL, 'Double', 2, FALSE); -- Occupped room 
INSERT INTO USER1.Rooms (id, type, capacity, availability) 
VALUES(hospital_dba.room_seq.NEXTVAL, 'Single', 1, TURE);
INSERT INTO USER1.Rooms (id, type, capacity, availability) 
VALUES(hospital_dba.room_seq.NEXTVAL, 'Double', 2, TRUE);

-- patient table 
INSERT INTO user1.Patients (id, name, date_of_birth, status, room_type) 
VALUES (hospital_dba.patient_seq.NEXTVAL, 'Ahmed Ismail', TO_DATE('1990-01-01', 'YYYY-MM-DD'), 'Admitted', 'Double');
INSERT INTO user1.Patients (id, name, date_of_birth, status, room_type) 
VALUES (hospital_dba.patient_seq.NEXTVAL, 'Sara Haithm', TO_DATE('1990-01-01', 'YYYY-MM-DD'), 'Admitted', 'Double');
INSERT INTO user1.Patients (id, name, date_of_birth, status, room_type) 
VALUES (hospital_dba.patient_seq.NEXTVAL, 'Micheal Doe', TO_DATE('1990-01-01', 'YYYY-MM-DD'), 'Admitted', 'Double');
INSERT INTO user1.Patients (id, name, date_of_birth, status, room_type) 
VALUES (hospital_dba.patient_seq.NEXTVAL, 'Mark Doe', TO_DATE('1985-05-12', 'YYYY-MM-DD'), 'Admitted', 'Double');
INSERT INTO user1.Patients (id, name, date_of_birth, status, room_type) 
VALUES (hospital_dba.patient_seq.NEXTVAL, 'Jhan Doe', TO_DATE('1985-05-12', 'YYYY-MM-DD'), 'Admitted', 'Double');


-- Features Implementation

--- 1.Patient Admission Validation and 4 features are achieved using this trigger 
/*
    THE BREAK DOWN OF THE TALBES INCLUDED IN THIS TRIGGER 
    1. ROOMS
    2. PATIENTS ( assign room if available)
    3. AUDITTRAIL
    TRIGER WILL WORK BEFORE AN INSERT OPERATION 
    ON EASH ROW ON PATIENT TABLE
**/

CREATE OR REPLACE TRIGGER patient_validation_trg
BEFORE INSERT ON user1.PATIENTS 
FOR EACH ROW 
DECLARE 
    assigned_room_id NUMBER;
BEGIN 
     -- 1: check for an available room of the requested type
     -- MIN(id) TO GET THE FIRST AVAILABLE ROOM 
    SELECT MIN(id) INTO assigned_room_id
    FROM user1.Rooms
    WHERE type = :NEW.room_type 
          AND availability = TRUE;
          
    --- case when no available rooms with requested type 
    
    IF assigned_room_id IS NULL THEN
        -- 2: raise an error if no rooms are available
        RAISE_APPLICATION_ERROR(-20001, 'No rooms of the requested type are available.');
    ELSE
        -- 3: Assign the room to the patient
        :NEW.room_id := assigned_room_id;

        -- 4: Update room availability (set to FALSE since the room is now occupied)
        UPDATE user1.Rooms
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
    END IF;
        
END;

--- test data to test trigger
INSERT INTO user1.Patients (id, name, date_of_birth, status, room_type) 
VALUES (patient_seq.NEXTVAL, 'Mohamed Ismail', TO_DATE('1990-01-01', 'YYYY-MM-DD'), 'Admitted', 'Double');
--- Causes the raising 
INSERT INTO user1.Patients (id, name, date_of_birth, status, room_type) 
VALUES (patient_seq.NEXTVAL, 'Abdullah Hisham', TO_DATE('1990-01-01', 'YYYY-MM-DD'), 'Admitted', 'Single'); 






-- 10. the Simultaion of blocker-waiting 
-- Session 1 (User 1)
UPDATE Rooms SET Availability = False WHERE id = 1;
-- Do not commit.

-- Session 2 (User 2)
UPDATE user1.Rooms SET Availability = True WHERE id = 1; -- This session will now wait because the row is locked by Session 1.



--11. Query for Identifying Blocker and Waiting Sessions
SELECT
    a.SID,
    a.SERIAL#,
    a.BLOCKING_SESSION,
    b.SID AS BLOCKER_SID,
    b.SERIAL# AS BLOCKER_SERIAL#
FROM
    V$SESSION a
    LEFT JOIN V$SESSION b ON a.BLOCKING_SESSION = b.SID
WHERE
    a.BLOCKING_SESSION IS NOT NULL;
