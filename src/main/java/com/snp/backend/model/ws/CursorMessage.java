package com.snp.backend.model.ws;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

public class CursorMessage {
    private String userId;
    private String projectId;
    private double x;
    private double y;
    private String color; // Hex color code

    public CursorMessage() {
    }

    public CursorMessage(String userId, String projectId, double x, double y, String color) {
        this.userId = userId;
        this.projectId = projectId;
        this.x = x;
        this.y = y;
        this.color = color;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getProjectId() {
        return projectId;
    }

    public void setProjectId(String projectId) {
        this.projectId = projectId;
    }

    public double getX() {
        return x;
    }

    public void setX(double x) {
        this.x = x;
    }

    public double getY() {
        return y;
    }

    public void setY(double y) {
        this.y = y;
    }

    public String getColor() {
        return color;
    }

    public void setColor(String color) {
        this.color = color;
    }
}
