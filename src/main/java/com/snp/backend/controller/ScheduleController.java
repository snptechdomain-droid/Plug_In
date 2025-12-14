package com.snp.backend.controller;

import com.snp.backend.model.ScheduleEntry;
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

    @GetMapping
    public List<ScheduleEntry> getAllEntries() {
        return scheduleRepository.findAll();
    }

    @PostMapping
    public ScheduleEntry createEntry(@RequestBody ScheduleEntry entry) {
        if (entry.getDate() == null) {
            entry.setDate(LocalDateTime.now());
        }
        return scheduleRepository.save(entry);
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
