<?php

use App\Jobs\CalculatePiJob;

test('calculation jobs use the default queue connection', function () {
    $job = new CalculatePiJob(1, 0, 100_000);

    expect($job->connection)->toBeNull();
});

test('queue retry_after exceeds calculation job timeout', function () {
    $job = new CalculatePiJob(1, 0, 100_000);

    expect(config('queue.connections.database.retry_after'))->toBeGreaterThan($job->timeout);
    expect(config('queue.connections.redis.retry_after'))->toBeGreaterThan($job->timeout);
});
