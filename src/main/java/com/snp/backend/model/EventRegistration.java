package com.snp.backend.model;

import java.time.LocalDateTime;

public class EventRegistration {
    private String name;
    private String phoneNumber;
    private String email;
    private String registerNumber;
    private String studentClass;
    private String year;
    private String department;
    private LocalDateTime registeredAt;

    public EventRegistration() {
        this.registeredAt = LocalDateTime.now();
    }

    public EventRegistration(String name, String phoneNumber, String email, String registerNumber, String studentClass,
            String year, String department) {
        this.name = name;
        this.phoneNumber = phoneNumber;
        this.email = email;
        this.registerNumber = registerNumber;
        this.studentClass = studentClass;
        this.year = year;
        this.department = department;
        this.registeredAt = LocalDateTime.now();
    }

    // Getters and Setters
    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getPhoneNumber() {
        return phoneNumber;
    }

    public void setPhoneNumber(String phoneNumber) {
        this.phoneNumber = phoneNumber;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getRegisterNumber() {
        return registerNumber;
    }

    public void setRegisterNumber(String registerNumber) {
        this.registerNumber = registerNumber;
    }

    public String getStudentClass() {
        return studentClass;
    }

    public void setStudentClass(String studentClass) {
        this.studentClass = studentClass;
    }

    public String getYear() {
        return year;
    }

    public void setYear(String year) {
        this.year = year;
    }

    public String getDepartment() {
        return department;
    }

    public void setDepartment(String department) {
        this.department = department;
    }

    public LocalDateTime getRegisteredAt() {
        return registeredAt;
    }

    public void setRegisteredAt(LocalDateTime registeredAt) {
        this.registeredAt = registeredAt;
    }
}
