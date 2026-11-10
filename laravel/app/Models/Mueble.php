<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Mueble extends Model
{
    protected $fillable = ['nombre', 'descripcion', 'precio', 'stock', 'categoria'];
}
