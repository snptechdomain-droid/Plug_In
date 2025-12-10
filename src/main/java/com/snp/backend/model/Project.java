package com.snp.backend.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;
import java.util.List;
import java.util.Map;

@Document(collection = "projects")
public class Project {
    @Id
    private String id;

    private String ownerId;
    private String title;
    private String thumbnailUrl;
    private List<String> collaboratorIds;
    private List<Poll> polls;
    private boolean isPublic;

    // Roles: UserId -> Role (e.g. "EDITOR", "VIEWER")
    private Map<String, String> memberRoles;

    // Tool Data (Embedded for simplicity)
    private String flowchartData;
    private String mindmapData;
    private String timelineData;

    @CreatedDate
    private Instant createdAt;

    @LastModifiedDate
    private Instant updatedAt;

    public Project() {
        this.polls = new java.util.ArrayList<>();
        this.memberRoles = new java.util.HashMap<>();
    }

    public Project(String id, String ownerId, String title, String thumbnailUrl,
            List<String> collaboratorIds, boolean isPublic, Instant createdAt, Instant updatedAt) {
        this.id = id;
        this.ownerId = ownerId;
        this.title = title;
        this.thumbnailUrl = thumbnailUrl;
        this.collaboratorIds = collaboratorIds;
        this.isPublic = isPublic;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
        this.polls = new java.util.ArrayList<>();
        this.memberRoles = new java.util.HashMap<>();
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getOwnerId() {
        return ownerId;
    }

    public void setOwnerId(String ownerId) {
        this.ownerId = ownerId;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getThumbnailUrl() {
        return thumbnailUrl;
    }

    public void setThumbnailUrl(String thumbnailUrl) {
        this.thumbnailUrl = thumbnailUrl;
    }

    public List<String> getCollaboratorIds() {
        return collaboratorIds;
    }

    public void setCollaboratorIds(List<String> collaboratorIds) {
        this.collaboratorIds = collaboratorIds;
    }

    public boolean isPublic() {
        return isPublic;
    }

    public void setPublic(boolean isPublic) {
        this.isPublic = isPublic;
    }

    public Map<String, String> getMemberRoles() {
        return memberRoles;
    }

    public void setMemberRoles(Map<String, String> memberRoles) {
        this.memberRoles = memberRoles;
    }

    public List<Poll> getPolls() {
        return polls;
    }

    public void setPolls(List<Poll> polls) {
        this.polls = polls;
    }

    public String getFlowchartData() {
        return flowchartData;
    }

    public void setFlowchartData(String flowchartData) {
        this.flowchartData = flowchartData;
    }

    public String getMindmapData() {
        return mindmapData;
    }

    public void setMindmapData(String mindmapData) {
        this.mindmapData = mindmapData;
    }

    public String getTimelineData() {
        return timelineData;
    }

    public void setTimelineData(String timelineData) {
        this.timelineData = timelineData;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }
}
