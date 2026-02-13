<?php

use App\Http\Controllers\Api\CalculateController;
use Illuminate\Support\Facades\Route;

Route::post('/calculate', [CalculateController::class, 'store']);
Route::get('/calculate/{calculation}', [CalculateController::class, 'show']);
