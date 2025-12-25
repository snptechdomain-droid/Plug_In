package com.snp.backend.model;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
import java.time.LocalDateTime;

@Document(collection = "schedule_entries")
public class ScheduleEntry {
    @Id
    private String id;
    private String title;
    private String description;
    private LocalDateTime date; // For specific date and time
    private String type; // CLASS, EXAM, HOLIDAY, MEETING
    private String venue;
    private String createdBy;

    public ScheduleEntry() {
    }

    public ScheduleEntry(String title, String description, LocalDateTime date, String type, String venue,
            String createdBy) {
        this.title = title;
        this.description = description;
        this.date = date;
        this.type = type;
        this.venue = venue;
        this.createdBy = createdBy;
    }

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

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public String getVenue() {
        return venue;
    }

    public void setVenue(String venue) {
        this.venue = venue;
    }

    public String getCreatedBy() {
        return createdBy;
    }

    public void setCreatedBy(String createdBy) {
        this.createdBy = createdBy;
    }
}
