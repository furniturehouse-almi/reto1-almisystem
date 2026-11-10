<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>The Furniture in Your House</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-light">
<nav class="navbar navbar-dark bg-dark mb-4">
    <div class="container">
        <a class="navbar-brand" href="{{ route('muebles.index') }}">The Furniture in Your House</a>
        @auth
            <div class="d-flex align-items-center text-white">
                <span class="me-3">{{ auth()->user()->name }} ({{ auth()->user()->role }})</span>
                <form action="{{ route('logout') }}" method="POST">
                    @csrf
                    <button class="btn btn-sm btn-outline-light">Salir</button>
                </form>
            </div>
        @endauth
    </div>
</nav>
<main class="container">
    @if (session('ok'))
        <div class="alert alert-success">{{ session('ok') }}</div>
    @endif
    @yield('content')
</main>
</body>
</html>
