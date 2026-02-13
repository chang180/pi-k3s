<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('calculations', function (Blueprint $table) {
            $table->id();
            $table->string('uuid')->unique();
            $table->unsignedInteger('total_points');
            $table->string('mode')->default('single');
            $table->string('status')->default('pending');
            $table->decimal('result_pi', 20, 18)->nullable();
            $table->unsignedInteger('result_inside')->nullable();
            $table->unsignedInteger('result_total')->nullable();
            $table->unsignedInteger('duration_ms')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('calculations');
    }
};
