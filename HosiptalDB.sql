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
    total_bill NUMBER(10, 2) DEFAULT 0, -- iNCLUDES (TREATMENT AND ROOM FEES) 
    room_type VARCHAR2(50) NOT NULL, -- Type of room requested
    room_id NUMBER, -- ID of the assigned room
    admission_date DATE, -- THE DATE THE PATIENT REGISTER IN HOSPITAL
    discharge_date DATE, -- THE DATE THE PATIENT CHECKOUT AND PAY TOTAL_BILL 
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


/*
    Assume that doctors will be available every day, so no need to add available days 
    Just available hours, but for query optimization purpose we'll store it as a two vars 
    start_hour -> the start of available slot 
    end_hour -> the end of available slot 
    for example if he'll be Available from 5AM : 8PM 
    THE START WILL BE 5AM 
    THE END WILL BE 8PM 
    THE DATATYPE OF THESE COLS WILL BE DATE 
    FOR FLEX COMPARISON IN THE RESERVATION OF AN APPOINTMENT
    AND SO ON...
*/
-- Doctors Table
CREATE TABLE Doctors (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    specialty VARCHAR2(100) NOT NULL,
    -- available hours wil mspped into two columns 
    start_hour DATE,
    end_hour DATE
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


SET AUTOCOMMIT ON;  -- to automatically commit changes 


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


-- 2. Appointmen Schedule 
CREATE OR REPLACE PROCEDURE Appointment_Schedule (
    p_doctor_id IN NUMBER,
    p_appointment_time IN DATE,
    p_patient_id IN NUMBER
) IS
    reserved_appointments NUMBER; -- To get the total number of appointments reserved at the same time
    doctor_start DATE;
    doctor_end DATE;
BEGIN
    -- Fetch the doctor's working hours
    SELECT start_hour, end_hour
    INTO doctor_start, doctor_end
    FROM Doctors
    WHERE id = p_doctor_id;

    -- Check if the time slot is already reserved
    SELECT COUNT(*)
    INTO reserved_appointments
    FROM Appointments
    WHERE appointment_date = p_appointment_time AND doctor_id = p_doctor_id;

    -- Handle reservation conflicts or invalid times
    IF reserved_appointments > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Time ' || TO_CHAR(p_appointment_time, 'YYYY-MM-DD HH24:MI:SS') || ' is already reserved.');
        RAISE_APPLICATION_ERROR(-20001, 'The time of the appointment is not available.');
    ELSIF p_appointment_time NOT BETWEEN doctor_start AND doctor_end THEN
        RAISE_APPLICATION_ERROR(-20001, 'The time of the appointment is not within the doctor''s working hours.');
    ELSE
        -- Insert the appointment and mark it as scheduled
        INSERT INTO Appointments(id, patient_id, doctor_id, appointment_date, status)
        VALUES (appointment_seq.NEXTVAL, p_patient_id, p_doctor_id, p_appointment_time, 'Scheduled');
    END IF;
END;

-- test the procedure 

-- insert a test doctors 
INSERT INTO Doctors (id, name, specialty, start_hour, end_hour)
VALUES (doctor_seq.nextval, 'Dr. Smith', 'Cardiology', TO_DATE('2024-12-07 09:00:00', 'YYYY-MM-DD HH24:MI:SS'), 
                                     TO_DATE('2024-12-07 17:00:00', 'YYYY-MM-DD HH24:MI:SS'));
                                     
INSERT INTO Doctors (id, name, specialty, start_hour, end_hour)
VALUES (doctor_seq.nextval, 'Dr. Jones', 'Neurology', TO_DATE('2024-12-07 08:00:00', 'YYYY-MM-DD HH24:MI:SS'), 
                                     TO_DATE('2024-12-07 16:00:00', 'YYYY-MM-DD HH24:MI:SS'));
                                     
-- insert a reserved appointment 
INSERT INTO Appointments (id, patient_id, doctor_id, appointment_date, status)
VALUES (appointment_seq.nextval,22 , 1, TO_DATE('2024-12-07 10:00:00', 'YYYY-MM-DD HH24:MI:SS'), 'Scheduled');

-- exec Appointment_Schedule  

-- first case valid appointment time 
BEGIN
    Appointment_Schedule(p_doctor_id => 1,
                         p_appointment_time => TO_DATE('2024-12-07 11:00:00', 'YYYY-MM-DD HH24:MI:SS'),
                         p_patient_id => 23);
END;
-- Verify the result
SELECT * FROM Appointments WHERE doctor_id = 1 AND appointment_date = TO_DATE('2024-12-07 11:00:00', 'YYYY-MM-DD HH24:MI:SS');

-- second case outside working hours (done)
BEGIN
    Appointment_Schedule(p_doctor_id => 1,
                         p_appointment_time => TO_DATE('2024-12-07 18:00:00', 'YYYY-MM-DD HH24:MI:SS'),
                         p_patient_id => 103);
END;

-- third case Conflicting appointment time (done)
BEGIN
    Appointment_Schedule(p_doctor_id => 1,
                         p_appointment_time => TO_DATE('2024-12-07 10:00:00', 'YYYY-MM-DD HH24:MI:SS'),
                         p_patient_id => 104);
END;


-- 3. Treatment Cost Calc

CREATE OR REPLACE FUNCTION Calculate_Treatment_Cost(p_patient_id NUMBER)
RETURN NUMBER IS
    total_cost NUMBER(10, 2);
BEGIN
    -- Aggregate the total cost of treatments for the given patient
    SELECT NVL(SUM(cost), 0)
    INTO total_cost
    FROM Treatments
    WHERE patient_id = p_patient_id;

    -- Update the total_bill column in the Patients table by adding the total_cost to it 
    UPDATE user1.Patients
    SET total_bill = total_bill + total_cost
    WHERE id = p_patient_id;

    -- Return the total cost for reference
    RETURN total_cost;
END;

-- Test Func, Firslty Insert Sample data and then Calculate the total Cost for a Pateitn
    INSERT INTO Treatments (id, patient_id, doctor_id, treatment_description, cost)
    VALUES (treatment_seq.nextval, 22, 1, 'General Checkup', 50.00);
    
    INSERT INTO Treatments (id, patient_id, doctor_id, treatment_description, cost)
    VALUES (treatment_seq.nextval, 22, 1, 'X-Ray', 100.00);
    
    INSERT INTO Treatments (id, patient_id, doctor_id, treatment_description, cost)
    VALUES (treatment_seq.nextval, 23, 2, 'Blood Test', 75.00);

DECLARE
    total NUMBER;
BEGIN
    total := Calculate_Treatment_Cost(22); -- output is 150 
    DBMS_OUTPUT.PUT_LINE('Total Treatment Cost for Patient 1: ' || total);
END;

-- 5. Discharge Processing 
CREATE OR REPLACE PROCEDURE Dishcarge_patient(patient_id number)
is 
    reserved_room number;
    old_data CLOB; -- To Store old date 
    new_data CLOB;
BEGIN   
    Select JSON_OBJECT(
                'id' value id,
                'name' value name,
                'date_of_birth' value date_of_birth,
                'status' value status, -- Admitted, Discharged, etc.
                'total_bill' value total_bill,
                'room_type' value room_type, -- Type of room requested
                'room_id' value room_id)
        INTO old_data
        FROM user1.Patients
        WHERE id = patient_id;
    
    -- This will cause the room to be available in case when it assigned to another patient 
    -- which will violate data integriy 
    IF status = 'Discharged' THEN 
       RAISE_APPLICATION_ERROR(-20001, 'Patient already been Discharged.');
    END IF;
    
    -- Fetch room_id 
    SELECT room_id
    INTO reserved_room
    FROM USER1.Patients
    WHERE id = patient_id;
    
    --- update patient status
    UPDATE USER1.PATIENTS 
    SET status = 'Discharged'
    WHERE id = patient_id;
    COMMIT;
    
    -- update the room availability 
    UPDATE USRE1.Rooms
    SET availability = TRUE
    WHERE id = reserved_room;
    
    COMMIT;
    
    Select JSON_OBJECT(
                'id' value id,
                'name' value name,
                'date_of_birth' value date_of_birth,
                'status' value status, -- Admitted, Discharged, etc.
                'total_bill' value total_bill,
                'room_type' value room_type, -- Type of room requested
                'room_id' value room_id)
        INTO new_data
        FROM user1.Patients
        WHERE id = patient_id;
    -- Log discharge data into AuditTrail
    INSERT INTO AuditTrail (id, table_name, operation ,old_data, new_data, timestamp)
    VALUES (audit_seq.NEXTVAL,'Patients', 'Discharge', old_data, new_data, SYSTIMESTAMP); 
END;

--- Testing the Procedure 

Declare 
    patient_row user1.patients%ROWTYPE;
    room_row user1.rooms%ROWTYPE;
    audit_row AuditTrail%ROWTYPE;
    room number;
BEGIN
     Dishcarge_patient(27);
     SELECT * INTO patient_row
     FROM user1.Patients 
     WHERE id = 27;  -- Replace 27 with a valid patient ID
     
     SELECT  room_id into room 
     FROM user1.Patients
     WHERE id = 27;
     
     DBMS_OUTPUT.PUT_LINE('Patient Status: ' || patient_row.status);
     
     SELECT * INTO room_row
     FROM user1.Rooms
     WHERE id = room;
     
     DBMS_OUTPUT.PUT_LINE('Room Availability: ' ||BooleanToString( room_row.availability));

     SELECT * INTO audit_row
     FROM AuditTrail
     WHERE table_name = 'Patients' AND operation = 'Discharge';
     DBMS_OUTPUT.PUT_LINE('Audit operation: ' || audit_row.operation);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Patient or Room not found');
        -- Handle any other exception scenarios
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error occurred: ' || SQLERRM);
END;


        
-- 6.Hospital Performance report 
Declare 
    -- Variables to hold the report data
    v_total_admissions    NUMBER;
    v_total_discharges    NUMBER;
    v_avg_stay_duration   NUMBER;
    
    
    --- CURSOR Declration 
    CURSOR c_top_doctors IS
       SELECT t.doctor_id, d.name ,COUNT(*) AS treatments_handled
        FROM treatments t
        inner join doctors d
        on t.doctor_id = d.id
        GROUP BY doctor_id, d.name
        ORDER BY treatments_handled DESC
        FETCH FIRST 3 ROWS ONLY;
        
     -- Record type for doctor data
    TYPE doctor_rec IS RECORD (
        doctor_id NUMBER,     
        doctor_name  VARCHAR2(100),
        treatments_handled NUMBER
    );

    -- Variable to hold a doctor record
    v_doctor doctor_rec;
        
Begin 

     -- Calculate total admissions
    SELECT COUNT(*) INTO v_total_admissions
    FROM user1.patients
    where status='Admitted';

    -- Calculate total discharges
    SELECT COUNT(*) INTO v_total_discharges
    FROM user1.patients
    where status='Discharged';

    -- Calculate average stay duration
    SELECT AVG(discharge_date - admission_date) INTO v_avg_stay_duration
    FROM user1.patients
    WHERE discharge_date IS NOT NULL;

    -- Output the report
    DBMS_OUTPUT.PUT_LINE('Hospital Performance Report');
    DBMS_OUTPUT.PUT_LINE('---------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Total Admissions: ' || v_total_admissions);
    DBMS_OUTPUT.PUT_LINE('Total Discharges: ' || v_total_discharges);
    DBMS_OUTPUT.PUT_LINE('Average Patient Stay Duration: ' || ROUND(v_avg_stay_duration, 2) || ' days');
    DBMS_OUTPUT.PUT_LINE('---------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Top 3 Doctors Based on Treatments:');
    DBMS_OUTPUT.PUT_LINE('Doctor ID | Doctor Name | Treatments Handled');

    -- Open the cursor for top doctors
    OPEN c_top_doctors;

    -- Loop through the cursor to get top three doctors
    LOOP
        FETCH c_top_doctors INTO v_doctor;

        EXIT WHEN c_top_doctors%NOTFOUND;

        -- Output each doctor's details
        DBMS_OUTPUT.PUT_LINE(v_doctor.doctor_id || ' | ' || v_doctor.doctor_name || ' | ' || v_doctor.treatments_handled);
    END LOOP;

    -- Close the cursor
    CLOSE c_top_doctors;
    
end;
-- TODO insert in Treatments test data 

-- 7. Cancle appointment in one transaction 
declare 
    appoint_row appointment%rowtype;
    cursor c_appointments
    is 
        select * from appointments 
        where appointment_date < SYSDATE
        AND  STATUS = 'Scheduled';
        
begin 
    LOOP
        FETCH c_appointments INTO appoint_row;            
       
    END LOOP;
end;

/*  
    Explanation 
    
    1.Cursor (PatientCursor):
        Fetches all patients who either missed appointments or delayed bill payments.
    2.Insert Warning:
        Adds a record to the Warnings table for each patient meeting the criteria.
    3.Count Warnings:
        Checks if the patient has three or more warnings.
    4.Update Status:
        Changes the patient's status to "Flagged" if warnings reach the threshold.
    5.AuditTrail Logging:
        Logs the old and new statuses in the AuditTrail table.
*/

-- 8. Patient Warnings and Status Update 
create or replace NONEDITIONABLE PROCEDURE IssueWarnings IS
    --- Declare a cursor to fetch all paient that missed 
    CURSOR PatientCursor IS
        SELECT p.id AS patient_id, 
               COUNT(w.id) AS warning_count
        FROM user1.Patients p
        LEFT JOIN Warnings w ON p.id = w.patient_id
        WHERE EXISTS (
            SELECT 1 
            FROM Appointments a
            WHERE a.patient_id = p.id 
              AND a.status = 'Canceled'
        ) OR p.total_bill > 0 -- Assuming unpaid bill is indicated by a non-zero amount
        GROUP BY p.id;

    v_warning_reason VARCHAR2(255);
    v_warning_date DATE := SYSDATE;
    v_warning_count NUMBER;
    v_old_status VARCHAR2(50);
    v_new_status VARCHAR2(50) := 'Flagged';

BEGIN
    -- Loop through patients who meet warning conditions
    FOR PatientRecord IN PatientCursor LOOP
        -- Determine warning reason
        v_warning_reason := 'Missed appointment or unpaid bill';

        -- Insert warning
        INSERT INTO Warnings (id, patient_id, warning_reason, warning_date)
        VALUES (warning_seq.NEXTVAL, PatientRecord.patient_id, v_warning_reason, v_warning_date);

        -- Check total warnings
        SELECT COUNT(*) INTO v_warning_count
        FROM Warnings
        WHERE patient_id = PatientRecord.patient_id;

        -- If warnings reach 3, update the patient's status
        IF v_warning_count >= 3 THEN
            -- Get the old status
            SELECT status INTO v_old_status
            FROM user1.Patients
            WHERE id = PatientRecord.patient_id;

            -- Update patient status
            UPDATE user1.Patients
            SET status = v_new_status
            WHERE id = PatientRecord.patient_id;
          
            -- Log the status update in AuditTrail
            INSERT INTO AuditTrail (id, table_name, operation, old_data, new_data, timestamp)
            VALUES (
                Audit_seq.NEXTVAL,
                'Patients',
                'UPDATE',
                'Old Status: ' || v_old_status,
                'New Status: ' || v_new_status,
                SYSDATE
            );
        commit; -- commit changes occurred 
            
        END IF;
    END LOOP;
END;
--Test the Procedure 

-- Insert into Appointments table

-- Insert a canceled appointment
INSERT INTO Appointments (id, patient_id, doctor_id, appointment_date, status)
VALUES (appointment_seq.NEXTVAL, 23, 1, SYSDATE - 2, 'Canceled');

-- Insert a completed appointment
INSERT INTO Appointments (id, patient_id, doctor_id, appointment_date, status)
VALUES (appointment_seq.NEXTVAL, 24, 2, SYSDATE - 10, 'Completed');

-- Insert a scheduled appointment
INSERT INTO Appointments (id, patient_id, doctor_id, appointment_date, status)
VALUES (appointment_seq.NEXTVAL, 25, 2, SYSDATE + 5, 'Scheduled');

-- Insert into Warnings table (simulate a previous warning)
INSERT INTO Warnings (id, patient_id, warning_reason, warning_date)
VALUES (warning_seq.NEXTVAL, 23, 'Missed appointment', SYSDATE - 3);

BEGIN
    IssueWarnings;
END;

-- Check the Warnings Table: Ensure the warning was added for the patients meeting the conditions.
SELECT * FROM Warnings; 

-- Check the Patients Table: Confirm the status of flagged patients has been updated
SELECT * FROM user1.Patients; -- patient 23 named marks' status  is been updated
--- verify logging
SELECT * FROM AuditTrail;



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


-- Utilities 

-- Convert boolean to String to print it  
CREATE OR REPLACE FUNCTION BooleanToString(value BOOLEAN) RETURN VARCHAR2 IS
BEGIN
    IF value IS NULL THEN
        RETURN 'NULL';
    ELSIF value THEN
        RETURN 'Available';
    ELSE
        RETURN 'Not Available';
    END IF;
END;


-- A deadlock occurs because Session 1(by user1) and Session 2 (by user2) are waiting for each other to release locks.
select * from user1.rooms;
-- to handle deadlock 
DECLARE
    deadlock_ex EXCEPTION;
    PRAGMA EXCEPTION_INIT(deadlock_ex, -60);
BEGIN
    -- First transaction
    UPDATE user1.patients SET room_id = 2 WHERE id = 23;
    UPDATE user1.rooms SET availability = 'False' WHERE id = 22;
EXCEPTION
    WHEN deadlock_ex THEN
        DBMS_OUTPUT.PUT_LINE('Deadlock detected! Retrying transaction...');
        ROLLBACK;
        -- Retry logic here, if necessary
END;
/

