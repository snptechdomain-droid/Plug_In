package com.snp.backend.model;

import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

@Data
@NoArgsConstructor
@Document(collection = "announcements")
public class Announcement {
    @Id
    private String id;
    private String title;
    private String content;
    private Instant date;
    private String authorName; // Display name of creator

    public Announcement(String title, String content, String authorName) {
        this.title = title;
        this.content = content;
        this.authorName = authorName;
        this.date = Instant.now();
    }

    // Manual Getters and Setters to fix compilation if Lombok fails
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

    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }

    public Instant getDate() {
        return date;
    }

    public void setDate(Instant date) {
        this.date = date;
    }

    public String getAuthorName() {
        return authorName;
    }

    public void setAuthorName(String authorName) {
        this.authorName = authorName;
    }
}
