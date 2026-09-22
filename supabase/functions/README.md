# Supabase Functions

## Funcion: send-cliente-afiliado-email

Envia el correo de alta de afiliacion con QR.

Ruta:
- supabase/functions/send-cliente-afiliado-email/index.ts

### Variables de entorno requeridas

- RESEND_API_KEY
- RESEND_FROM

### Deploy

1. Vincula el proyecto de Supabase CLI.
2. Despliega la funcion:

supabase functions deploy send-cliente-afiliado-email

3. Configura secrets:

supabase secrets set RESEND_API_KEY=... RESEND_FROM="Osyra <afiliacion@tu-dominio.com>"
