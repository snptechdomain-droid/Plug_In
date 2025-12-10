package com.snp.backend.model;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
import java.time.Instant;
import java.util.List;

@Document(collection = "attendance")
public class Attendance {
    @Id
    private String id;
    private Instant date;
    private List<String> presentUserIds;
    private String notes;

    public Attendance() {
    }

    public Attendance(Instant date, List<String> presentUserIds, String notes) {
        this.date = date;
        this.presentUserIds = presentUserIds;
        this.notes = notes;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public Instant getDate() {
        return date;
    }

    public void setDate(Instant date) {
        this.date = date;
    }

    public List<String> getPresentUserIds() {
        return presentUserIds;
    }

    public void setPresentUserIds(List<String> presentUserIds) {
        this.presentUserIds = presentUserIds;
    }

    public String getNotes() {
        return notes;
    }

    public void setNotes(String notes) {
        this.notes = notes;
    }
}
