package com.snp.backend.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

@Document(collection = "users")
public class User {
    @Id
    private String id;

    @Indexed(unique = true)
    private String email;

    private String passwordHash;
    private String displayName;
    private String avatarUrl;
    private String bio;
    private boolean active = true;

    // New Fields
    private String domain;
    private String department;
    private String year;
    private String section;
    private String registerNumber;

    private Role role;

    @CreatedDate
    private Instant createdAt;

    private Instant lastAnnouncementRead;

    public enum Role {
        ADMIN,
        MODERATOR,
        EVENT_COORDINATOR,
        MEMBER
    }

    public User() {
    }

    public User(String id, String email, String passwordHash, String displayName, String avatarUrl, Role role,
            Instant createdAt) {
        this.id = id;
        this.email = email;
        this.passwordHash = passwordHash;
        this.displayName = displayName;
        this.avatarUrl = avatarUrl;
        this.role = role;
        this.createdAt = createdAt;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public void setPasswordHash(String passwordHash) {
        this.passwordHash = passwordHash;
    }

    public String getDisplayName() {
        return displayName;
    }

    public void setDisplayName(String displayName) {
        this.displayName = displayName;
    }

    public String getAvatarUrl() {
        return avatarUrl;
    }

    public void setAvatarUrl(String avatarUrl) {
        this.avatarUrl = avatarUrl;
    }

    public String getBio() {
        return bio;
    }

    public void setBio(String bio) {
        this.bio = bio;
    }

    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
    }

    public Role getRole() {
        return role;
    }

    public void setRole(Role role) {
        this.role = role;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getLastAnnouncementRead() {
        return lastAnnouncementRead;
    }

    public void setLastAnnouncementRead(Instant lastAnnouncementRead) {
        this.lastAnnouncementRead = lastAnnouncementRead;
    }

    private java.util.List<String> domains = new java.util.ArrayList<>();

    // ... (keeping other fields)

    public java.util.List<String> getDomains() {
        return domains;
    }

    public void setDomains(java.util.List<String> domains) {
        this.domains = domains;
    }

    // Helper to keep legacy compatibility for getDomain() if needed,
    // or just remove it. Removing it forces compile errors where we need to update.
    // I'll leave a helper for primary domain to minimize breakage temporarily?
    // User requested "multiple domains", so usually getDomain() implies primary.
    public String getDomain() {
        return (domains != null && !domains.isEmpty()) ? domains.get(0) : null;
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
}
