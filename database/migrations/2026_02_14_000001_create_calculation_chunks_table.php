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
        Schema::create('calculation_chunks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('calculation_id')->constrained()->cascadeOnDelete();
            $table->unsignedSmallInteger('chunk_index');
            $table->unsignedInteger('total_points');
            $table->unsignedInteger('result_inside')->nullable();
            $table->unsignedInteger('result_total')->nullable();
            $table->unsignedInteger('duration_ms')->nullable();
            $table->string('status')->default('pending'); // pending, completed
            $table->timestamps();

            $table->unique(['calculation_id', 'chunk_index']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('calculation_chunks');
    }
};
