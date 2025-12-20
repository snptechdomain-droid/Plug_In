package com.snp.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
@org.springframework.scheduling.annotation.EnableScheduling
public class BackendApplication {

	public static void main(String[] args) {
		System.out.println("Checking Auto Deployment...");
		SpringApplication.run(BackendApplication.class, args);
	}

}
