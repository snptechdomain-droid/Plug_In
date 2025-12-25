package com.snp.backend.controller;

import com.snp.backend.model.Event;
import com.snp.backend.repository.EventRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/events")
@CrossOrigin(origins = "*") // Allow all origins for mobile/web
public class EventController {

    @Autowired
    private EventRepository eventRepository;

    @Autowired
    private com.snp.backend.repository.AnnouncementRepository announcementRepository;

    @GetMapping
    public List<Event> getAllEvents() {
        return eventRepository.findAll();
    }

    @GetMapping("/public")
    public List<Event> getPublicEvents() {
        return eventRepository.findByIsPublicTrue();
    }

    @PostMapping
    public Event createEvent(@RequestBody Event event) {
        // Ensure date is set if not provided (optional safety)
        if (event.getDate() == null) {
            event.setDate(LocalDateTime.now());
        }
        Event savedEvent = eventRepository.save(event);

        // Automatically create an announcement
        try {
            com.snp.backend.model.Announcement announcement = new com.snp.backend.model.Announcement();
            announcement.setTitle("New Event: " + savedEvent.getTitle());
            announcement.setContent(savedEvent.getDescription());
            announcement.setAuthorName(savedEvent.getCreatedBy() != null ? savedEvent.getCreatedBy() : "Admin");
            announcement.setDate(java.time.Instant.now());
            announcementRepository.save(announcement);
        } catch (Exception e) {
            // Log error but don't fail event creation
            System.err.println("Failed to create announcement for event: " + e.getMessage());
        }

        return savedEvent;
    }

    @PutMapping("/{id}")
    public Event updateEvent(@PathVariable String id, @RequestBody Event eventDetails) {
        return eventRepository.findById(id).map(event -> {
            event.setTitle(eventDetails.getTitle());
            event.setDescription(eventDetails.getDescription());
            event.setDate(eventDetails.getDate());
            event.setVenue(eventDetails.getVenue());
            event.setPublic(eventDetails.isPublic());
            event.setRegistrationStarted(eventDetails.isRegistrationStarted());
            event.setImageUrl(eventDetails.getImageUrl());
            return eventRepository.save(event);
        }).orElseThrow(() -> new RuntimeException("Event not found"));
    }

    @DeleteMapping("/{id}")
    public void deleteEvent(@PathVariable String id) {
        eventRepository.deleteById(id);
    }

    @PostMapping("/{id}/register")
    public Event registerForEvent(@PathVariable String id,
            @RequestBody com.snp.backend.model.EventRegistration registration) {
        return eventRepository.findById(id).map(event -> {
            if (!event.isRegistrationStarted()) {
                throw new RuntimeException("Registration is not open for this event.");
            }
            event.addRegistration(registration);
            return eventRepository.save(event);
        }).orElseThrow(() -> new RuntimeException("Event not found"));
    }
}
