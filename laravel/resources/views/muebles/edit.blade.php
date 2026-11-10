@extends('layouts.app')

@section('content')
<h1 class="h3">Editar mueble</h1>
<form action="{{ route('muebles.update', $mueble) }}" method="POST">
    @csrf @method('PUT')
    @include('muebles._form')
</form>
@endsection
