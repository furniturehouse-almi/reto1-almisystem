@extends('layouts.app')

@section('content')
<h1 class="h3">Nuevo mueble</h1>
<form action="{{ route('muebles.store') }}" method="POST">
    @csrf
    @include('muebles._form')
</form>
@endsection
