package com.example.todo;

import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

import org.springframework.stereotype.Service;

@Service
public class TodoService {
    private final ConcurrentHashMap<Long, Todo> todos = new ConcurrentHashMap<>();
    private final AtomicLong nextId = new AtomicLong();

    public List<Todo> findAll() {
        return todos.values().stream()
                .sorted(Comparator.comparingLong(Todo::id))
                .toList();
    }

    public Optional<Todo> findById(long id) {
        return Optional.ofNullable(todos.get(id));
    }

    public Todo create(TodoRequest request) {
        long id = nextId.incrementAndGet();
        Todo todo = new Todo(id, request.title().trim(), request.completed(), Instant.now());
        todos.put(id, todo);
        return todo;
    }

    public Optional<Todo> update(long id, TodoRequest request) {
        return Optional.ofNullable(todos.computeIfPresent(id, (key, existing) ->
                new Todo(key, request.title().trim(), request.completed(), existing.createdAt())));
    }

    public boolean delete(long id) {
        return todos.remove(id) != null;
    }
}
