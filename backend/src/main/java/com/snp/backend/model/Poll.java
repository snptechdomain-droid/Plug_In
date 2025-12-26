package com.snp.backend.model;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.HashMap;
import java.util.ArrayList;

public class Poll {
    private String id;
    private String question;
    private List<String> options;
    private Map<String, Object> votes; // UserId -> Integer or List<Integer>
    private String createdBy;
    private Instant createdAt;
    private boolean active;
    private boolean multiSelect;

    public Poll() {
        this.id = UUID.randomUUID().toString();
        this.createdAt = Instant.now();
        this.active = true;
        this.multiSelect = false;
        this.votes = new HashMap<>();
    }

    public Poll(String question, List<String> options, String createdBy, boolean multiSelect) {
        this();
        this.question = question;
        this.options = options;
        this.createdBy = createdBy;
        this.multiSelect = multiSelect;
    }

    // Getters and Setters
    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getQuestion() {
        return question;
    }

    public void setQuestion(String question) {
        this.question = question;
    }

    public List<String> getOptions() {
        return options;
    }

    public void setOptions(List<String> options) {
        this.options = options;
    }

    public Map<String, Object> getVotes() {
        return votes;
    }

    public void setVotes(Map<String, Object> votes) {
        this.votes = votes;
    }

    public String getCreatedBy() {
        return createdBy;
    }

    public void setCreatedBy(String createdBy) {
        this.createdBy = createdBy;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
    }

    public boolean isMultiSelect() {
        return multiSelect;
    }

    public void setMultiSelect(boolean multiSelect) {
        this.multiSelect = multiSelect;
    }
}
