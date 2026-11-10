<?php

use App\Http\Controllers\LoginController;
use App\Http\Controllers\MuebleController;
use Illuminate\Support\Facades\Route;

Route::redirect('/', '/muebles');

Route::middleware('guest')->group(function () {
    Route::get('/login', [LoginController::class, 'show'])->name('login');
    Route::post('/login', [LoginController::class, 'login'])->middleware('throttle:5,1');
});

Route::middleware('auth')->group(function () {
    Route::post('/logout', [LoginController::class, 'logout'])->name('logout');

    // Empleados y admins pueden ver el catálogo
    Route::get('/muebles', [MuebleController::class, 'index'])->name('muebles.index');

    // Solo los admins pueden crear, editar y borrar
    Route::middleware('can:admin')->group(function () {
        Route::resource('muebles', MuebleController::class)->except(['index', 'show']);
    });
});
