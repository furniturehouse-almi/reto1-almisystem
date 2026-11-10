@if ($errors->any())
    <div class="alert alert-danger">
        <ul class="mb-0">
            @foreach ($errors->all() as $error)
                <li>{{ $error }}</li>
            @endforeach
        </ul>
    </div>
@endif

<div class="mb-3">
    <label class="form-label">Nombre</label>
    <input type="text" name="nombre" class="form-control" value="{{ old('nombre', $mueble->nombre ?? '') }}">
</div>
<div class="mb-3">
    <label class="form-label">Descripción</label>
    <textarea name="descripcion" class="form-control" rows="3">{{ old('descripcion', $mueble->descripcion ?? '') }}</textarea>
</div>
<div class="row">
    <div class="col-md-4 mb-3">
        <label class="form-label">Precio (€)</label>
        <input type="number" step="0.01" name="precio" class="form-control" value="{{ old('precio', $mueble->precio ?? '') }}">
    </div>
    <div class="col-md-4 mb-3">
        <label class="form-label">Stock</label>
        <input type="number" name="stock" class="form-control" value="{{ old('stock', $mueble->stock ?? 0) }}">
    </div>
    <div class="col-md-4 mb-3">
        <label class="form-label">Categoría</label>
        <input type="text" name="categoria" class="form-control" value="{{ old('categoria', $mueble->categoria ?? '') }}">
    </div>
</div>
<a href="{{ route('muebles.index') }}" class="btn btn-secondary">Cancelar</a>
<button class="btn btn-primary">Guardar</button>
