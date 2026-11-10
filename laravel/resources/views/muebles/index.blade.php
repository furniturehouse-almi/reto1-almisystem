@extends('layouts.app')

@section('content')
<div class="d-flex justify-content-between mb-3">
    <h1 class="h3">Catálogo de muebles</h1>
    @can('admin')
        <a href="{{ route('muebles.create') }}" class="btn btn-primary">Nuevo mueble</a>
    @endcan
</div>

<table class="table table-striped bg-white">
    <thead>
        <tr><th>Nombre</th><th>Categoría</th><th>Precio</th><th>Stock</th><th></th></tr>
    </thead>
    <tbody>
    @forelse ($muebles as $m)
        <tr>
            <td>{{ $m->nombre }}</td>
            <td>{{ $m->categoria }}</td>
            <td>{{ number_format($m->precio, 2) }} €</td>
            <td>{{ $m->stock }}</td>
            <td class="text-end">
                @can('admin')
                    <a href="{{ route('muebles.edit', $m) }}" class="btn btn-sm btn-outline-secondary">Editar</a>
                    <form action="{{ route('muebles.destroy', $m) }}" method="POST" class="d-inline"
                          onsubmit="return confirm('¿Eliminar este mueble?')">
                        @csrf @method('DELETE')
                        <button class="btn btn-sm btn-outline-danger">Borrar</button>
                    </form>
                @endcan
            </td>
        </tr>
    @empty
        <tr><td colspan="5" class="text-center">No hay muebles todavía.</td></tr>
    @endforelse
    </tbody>
</table>

{{ $muebles->links() }}
@endsection
