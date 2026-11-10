<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreMuebleRequest;
use App\Http\Requests\UpdateMuebleRequest;
use App\Models\Mueble;

class MuebleController extends Controller
{
    public function index()
    {
        $muebles = Mueble::latest()->paginate(10);
        return view('muebles.index', compact('muebles'));
    }

    public function create()
    {
        return view('muebles.create');
    }

    public function store(StoreMuebleRequest $request)
    {
        Mueble::create($request->validated());
        return redirect()->route('muebles.index')->with('ok', 'Mueble creado.');
    }

    public function edit(Mueble $mueble)
    {
        return view('muebles.edit', compact('mueble'));
    }

    public function update(UpdateMuebleRequest $request, Mueble $mueble)
    {
        $mueble->update($request->validated());
        return redirect()->route('muebles.index')->with('ok', 'Mueble actualizado.');
    }

    public function destroy(Mueble $mueble)
    {
        $mueble->delete();
        return redirect()->route('muebles.index')->with('ok', 'Mueble eliminado.');
    }
}
