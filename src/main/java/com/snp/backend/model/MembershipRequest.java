package com.snp.backend.model;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
import java.time.LocalDateTime;

@Document(collection = "membership_requests")
public class MembershipRequest {
    @Id
    private String id;
    private String name;
    private String email;
    private String reason;
    private String status; // PENDING, APPROVED, REJECTED
    private LocalDateTime requestDate;

    // New fields
    private String department;
    private String year;
    private String section;
    private String registerNumber;
    private String mobileNumber;

    public MembershipRequest() {
    }

    public MembershipRequest(String name, String email, String reason, String department, String year, String section,
            String registerNumber, String mobileNumber) {
        this.name = name;
        this.email = email;
        this.reason = reason;
        this.department = department;
        this.year = year;
        this.section = section;
        this.registerNumber = registerNumber;
        this.mobileNumber = mobileNumber;
        this.status = "PENDING";
        this.requestDate = LocalDateTime.now();
    }

    // Getters and Setters
    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getReason() {
        return reason;
    }

    public void setReason(String reason) {
        this.reason = reason;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public LocalDateTime getRequestDate() {
        return requestDate;
    }

    public void setRequestDate(LocalDateTime requestDate) {
        this.requestDate = requestDate;
    }

    public String getDepartment() {
        return department;
    }

    public void setDepartment(String department) {
        this.department = department;
    }

    public String getYear() {
        return year;
    }

    public void setYear(String year) {
        this.year = year;
    }

    public String getSection() {
        return section;
    }

    public void setSection(String section) {
        this.section = section;
    }

    public String getRegisterNumber() {
        return registerNumber;
    }

    public void setRegisterNumber(String registerNumber) {
        this.registerNumber = registerNumber;
    }

    public String getMobileNumber() {
        return mobileNumber;
    }

    public void setMobileNumber(String mobileNumber) {
        this.mobileNumber = mobileNumber;
    }
}
