package com.snp.backend.model.ws;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Map;

public class NodeMessage {
    private String type; // "ADD", "UPDATE", "DELETE"
    private String projectId;
    private String nodeId;
    private Map<String, Object> data; // Flexible JSON data for the node

    public NodeMessage() {
    }

    public NodeMessage(String type, String projectId, String nodeId, Map<String, Object> data) {
        this.type = type;
        this.projectId = projectId;
        this.nodeId = nodeId;
        this.data = data;
    }

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public String getProjectId() {
        return projectId;
    }

    public void setProjectId(String projectId) {
        this.projectId = projectId;
    }

    public String getNodeId() {
        return nodeId;
    }

    public void setNodeId(String nodeId) {
        this.nodeId = nodeId;
    }

    public Map<String, Object> getData() {
        return data;
    }

    public void setData(Map<String, Object> data) {
        this.data = data;
    }
}
