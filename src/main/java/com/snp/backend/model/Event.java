package com.snp.backend.model;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
import java.time.LocalDateTime;

@Document(collection = "events")
public class Event {
    @Id
    private String id;
    private String title;
    private String description;
    private LocalDateTime date;
    private String venue;
    private boolean registrationStarted;
    private String imageUrl;
    private java.util.List<EventRegistration> registrations = new java.util.ArrayList<>();

    public Event() {
        this.registrations = new java.util.ArrayList<>();
    }

    public Event(String title, String description, LocalDateTime date, String venue, boolean isPublic,
            String createdBy) {
        this.title = title;
        this.description = description;
        this.date = date;
        this.venue = venue;
        this.isPublic = isPublic;
        this.createdBy = createdBy;
        this.registrations = new java.util.ArrayList<>();
    }

    // Getters and Setters
    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public LocalDateTime getDate() {
        return date;
    }

    public void setDate(LocalDateTime date) {
        this.date = date;
    }

    public String getVenue() {
        return venue;
    }

    public void setVenue(String venue) {
        this.venue = venue;
    }

    public boolean isPublic() {
        return isPublic;
    }

    public void setPublic(boolean isPublic) {
        this.isPublic = isPublic;
    }

    public String getCreatedBy() {
        return createdBy;
    }

    public void setCreatedBy(String createdBy) {
        this.createdBy = createdBy;
    }

    public boolean isRegistrationStarted() {
        return registrationStarted;
    }

    public void setRegistrationStarted(boolean registrationStarted) {
        this.registrationStarted = registrationStarted;
    }

    public String getImageUrl() {
        return imageUrl;
    }

    public void setImageUrl(String imageUrl) {
        this.imageUrl = imageUrl;
    }

    public java.util.List<EventRegistration> getRegistrations() {
        return registrations;
    }

    public void setRegistrations(java.util.List<EventRegistration> registrations) {
        this.registrations = registrations;
    }

    public void addRegistration(EventRegistration registration) {
        if (this.registrations == null) {
            this.registrations = new java.util.ArrayList<>();
        }
        this.registrations.add(registration);
    }
}
