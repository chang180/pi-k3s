<?php

use App\Models\Calculation;

test('stream returns text/event-stream content type', function () {
    $calculation = Calculation::factory()->completed()->create();

    $response = $this->get("/api/calculate/{$calculation->id}/stream");

    $response->assertSuccessful();
    expect($response->headers->get('content-type'))->toContain('text/event-stream');
});

test('stream works with uuid route binding', function () {
    $calculation = Calculation::factory()->completed()->create();

    $response = $this->get("/api/calculate/{$calculation->uuid}/stream");

    $response->assertSuccessful();
    expect($response->headers->get('content-type'))->toContain('text/event-stream');
});

test('stream completes immediately for finished calculation', function () {
    $calculation = Calculation::factory()->completed()->create();

    $response = $this->get("/api/calculate/{$calculation->id}/stream");

    $response->assertSuccessful();
    $content = $response->streamedContent();
    expect($content)->toContain('event: update');
    expect($content)->toContain('"status":"completed"');
});

test('stream returns 404 for non-existent calculation', function () {
    $response = $this->get('/api/calculate/99999/stream');

    $response->assertNotFound();
});
