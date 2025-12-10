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
        return eventRepository.save(event);
    }

    @PutMapping("/{id}")
    public Event updateEvent(@PathVariable String id, @RequestBody Event eventDetails) {
        return eventRepository.findById(id).map(event -> {
            event.setTitle(eventDetails.getTitle());
            event.setDescription(eventDetails.getDescription());
            event.setDate(eventDetails.getDate());
            event.setVenue(eventDetails.getVenue());
            event.setPublic(eventDetails.isPublic());
            return eventRepository.save(event);
        }).orElseThrow(() -> new RuntimeException("Event not found"));
    }

    @DeleteMapping("/{id}")
    public void deleteEvent(@PathVariable String id) {
        eventRepository.deleteById(id);
    }
}
