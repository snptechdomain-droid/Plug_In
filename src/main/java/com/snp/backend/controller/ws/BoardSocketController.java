package com.snp.backend.controller.ws;

import com.snp.backend.model.ws.CursorMessage;
import com.snp.backend.model.ws.NodeMessage;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Controller;

@Controller
public class BoardSocketController {

    private final SimpMessagingTemplate messagingTemplate;

    public BoardSocketController(SimpMessagingTemplate messagingTemplate) {
        this.messagingTemplate = messagingTemplate;
    }

    /**
     * Handles cursor movements.
     * Client sends to: /app/project.moveCursor
     * Server broadcasts to: /topic/project.{projectId}.cursors
     */
    @MessageMapping("/project.moveCursor")
    public void moveCursor(@Payload CursorMessage message) {
        String destination = "/topic/project." + message.getProjectId() + ".cursors";
        messagingTemplate.convertAndSend(destination, message);
    }

    /**
     * Handles node updates (add, move, resize, delete).
     * Client sends to: /app/project.updateNode
     * Server broadcasts to: /topic/project.{projectId}
     */
    @MessageMapping("/project.updateNode")
    public void updateNode(@Payload NodeMessage message) {
        String destination = "/topic/project." + message.getProjectId();
        messagingTemplate.convertAndSend(destination, message);
    }
}
