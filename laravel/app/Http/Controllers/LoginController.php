<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class LoginController extends Controller
{
    public function show()
    {
        return view('auth.login');
    }

    public function login(Request $request)
    {
        $data = $request->validate([
            'username' => 'required|string',
            'password' => 'required|string',
        ]);

        if (Auth::attempt(['samaccountname' => $data['username'], 'password' => $data['password']])) {
            $request->session()->regenerate();
            return redirect()->intended(route('muebles.index'));
        }

        return back()
            ->withErrors(['username' => 'Usuario o contraseña incorrectos, o sin permiso de acceso.'])
            ->onlyInput('username');
    }

    public function logout(Request $request)
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login');
    }
}
