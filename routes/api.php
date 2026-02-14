<?php

use App\Http\Controllers\Api\CalculateController;
use App\Http\Controllers\Api\K8sStatusController;
use Illuminate\Support\Facades\Route;

Route::post('/calculate', [CalculateController::class, 'store']);
Route::get('/calculate/{calculation}', [CalculateController::class, 'show']);

Route::get('/k8s/status', [K8sStatusController::class, 'status']);
Route::get('/k8s/metrics', [K8sStatusController::class, 'metrics']);
