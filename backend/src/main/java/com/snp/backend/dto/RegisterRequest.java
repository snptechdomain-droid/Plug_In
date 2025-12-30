package com.snp.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

public class RegisterRequest {
    @NotBlank(message = "Username is required")
    @Size(min = 3, max = 50, message = "Username must be between 3 and 50 characters")
    private String username;

    @NotBlank(message = "Password is required")
    @Size(min = 6, message = "Password must be at least 6 characters")
    private String password;
    private String key;

    @NotBlank(message = "Name is required")
    private String name;

    // New Fields
    private String registerNumber;
    private String year;
    private String section;
    private String department;
    private String mobileNumber;
    private String domain;

    public RegisterRequest() {
    }

    public RegisterRequest(String username, String password, String key,
            String registerNumber, String year, String section,
            String department, String domain) {
        this.username = username;
        this.password = password;
        this.key = key;
        this.registerNumber = registerNumber;
        this.year = year;
        this.section = section;
        this.department = department;
        this.domain = domain;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public String getKey() {
        return key;
    }

    public void setKey(String key) {
        this.key = key;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getRegisterNumber() {
        return registerNumber;
    }

    public void setRegisterNumber(String registerNumber) {
        this.registerNumber = registerNumber;
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

    public String getDepartment() {
        return department;
    }

    public void setDepartment(String department) {
        this.department = department;
    }

    public String getMobileNumber() {
        return mobileNumber;
    }

    public void setMobileNumber(String mobileNumber) {
        this.mobileNumber = mobileNumber;
    }

    private java.util.List<String> domains;

    public java.util.List<String> getDomains() {
        return domains;
    }

    public void setDomains(java.util.List<String> domains) {
        this.domains = domains;
    }

    // Legacy single domain support
    public String getDomain() {
        return (domains != null && !domains.isEmpty()) ? domains.get(0) : null;
    }

    public void setDomain(String domain) {
        if (this.domains == null)
            this.domains = new java.util.ArrayList<>();
        this.domains.add(domain);
    }
}
