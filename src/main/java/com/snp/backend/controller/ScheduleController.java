package com.snp.backend.controller;

import com.snp.backend.model.Announcement;
import com.snp.backend.model.Event;
import com.snp.backend.model.ScheduleEntry;
import com.snp.backend.repository.AnnouncementRepository;
import com.snp.backend.repository.EventRepository;
import com.snp.backend.repository.ScheduleRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/schedule")
@CrossOrigin(origins = "*")
public class ScheduleController {

    @Autowired
    private ScheduleRepository scheduleRepository;

    @Autowired
    private EventRepository eventRepository;

    @Autowired
    private AnnouncementRepository announcementRepository;

    @GetMapping
    public List<ScheduleEntry> getAllEntries() {
        return scheduleRepository.findAll();
    }

    @PostMapping
    public ScheduleEntry createEntry(@RequestBody ScheduleEntry entry) {
        boolean isUpdate = entry.getId() != null && scheduleRepository.existsById(entry.getId());

        if (entry.getDate() == null) {
            entry.setDate(LocalDateTime.now());
        }
        ScheduleEntry saved = scheduleRepository.save(entry);

        // 1. Integrate with Events: Create an Event if this is a NEW schedule entry
        if (!isUpdate) {
            try {
                // Determine privacy based on type maybe? Defaulting to public as requested.
                // Assuming "from calendar" implies it should be visible.
                Event event = new Event(
                        saved.getTitle(),
                        saved.getDescription() != null ? saved.getDescription() : "Scheduled via Calendar",
                        saved.getDate(),
                        "TBD", // Venue
                        true, // isPublic
                        saved.getCreatedBy());
                eventRepository.save(event);
            } catch (Exception e) {
                System.err.println("Failed to sync Schedule to Event: " + e.getMessage());
            }
        }

        // 2. Integrate with Announcements: Notify on Create OR Update
        try {
            String author = saved.getCreatedBy() != null ? saved.getCreatedBy() : "System";
            String title = "Schedule Update";
            String content;

            if (saved.getVenue() != null && !saved.getVenue().isEmpty()) {
                content = String.format("An offline meet has been scheduled by %s at %s.", author, saved.getVenue());
            } else {
                content = String.format("A schedule entry '%s' was %s by %s.", saved.getTitle(),
                        isUpdate ? "updated" : "added", author);
            }

            Announcement announcement = new Announcement(title, content, author);
            announcementRepository.save(announcement);
        } catch (Exception e) {
            System.err.println("Failed to create Announcement for Schedule: " + e.getMessage());
        }

        return saved;
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteEntry(@PathVariable String id) {
        if (!scheduleRepository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }
        scheduleRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }
}
