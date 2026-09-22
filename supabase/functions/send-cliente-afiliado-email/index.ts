// @ts-nocheck
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import QRCode from "npm:qrcode@1.5.4";

type Payload = {
  clienteId: string;
  nombre: string;
  email: string;
  numeroAfiliado: string;
  dniCif: string;
  qrAuthCode: string;
  qrValue: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function baseHtml(content: string): string {
  return `
  <div style="font-family:Arial,Helvetica,sans-serif;background:#f3f6f7;padding:24px;">
    <div style="max-width:560px;margin:0 auto;background:#ffffff;border:1px solid #d9e3e6;border-radius:14px;padding:22px;">
      ${content}
    </div>
  </div>`;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    const resendFrom = Deno.env.get("RESEND_FROM") ?? "Osyra <afiliacion@osyra.local>";
    const resendForceTo = Deno.env.get("RESEND_FORCE_TO_EMAIL")?.trim() ?? "";

    if (!resendApiKey) {
      throw new Error("Falta RESEND_API_KEY en variables de entorno.");
    }

    const payload = (await req.json()) as Payload;
    if (
      !payload.email ||
      !payload.qrAuthCode ||
      !payload.qrValue ||
      !payload.nombre ||
      !payload.numeroAfiliado ||
      !payload.dniCif ||
      !payload.clienteId
    ) {
      return new Response(
        JSON.stringify({ error: "Payload incompleto para enviar correo de afiliacion." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const qrDataUrl = await QRCode.toDataURL(payload.qrValue, {
      width: 320,
      margin: 1,
      errorCorrectionLevel: "H",
      color: {
        dark: "#0B3D40",
        light: "#FFFFFF",
      },
    });

    const forceEnabled = resendForceTo.length > 0;
    const targetEmail = forceEnabled ? resendForceTo : payload.email;
    const demoNota = forceEnabled
      ? `<p style="margin:8px 0 0 0;color:#64748b;font-size:12px;">Modo pruebas activo: destinatario original ${payload.email}</p>`
      : "";

    const html = baseHtml(`
      <h2 style="margin:0 0 8px 0;color:#0f172a;">Bienvenido a Osyra, ${payload.nombre}</h2>
      <p style="margin:0 0 6px 0;color:#334155;">Tu alta de cliente afiliado esta completada.</p>
      <p style="margin:0 0 6px 0;color:#334155;"><strong>Numero afiliado:</strong> ${payload.numeroAfiliado}</p>
      <p style="margin:0 0 14px 0;color:#334155;"><strong>DNI/CIF:</strong> ${payload.dniCif}</p>

      <div style="text-align:center;background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;padding:14px;margin-bottom:14px;">
        <p style="margin:0 0 8px 0;color:#0f172a;font-weight:700;">QR de autenticacion en tienda</p>
        <img alt="QR afiliado Osyra" src="${qrDataUrl}" width="220" height="220" style="max-width:100%;height:auto;" />
        <p style="margin:10px 0 0 0;color:#475569;font-size:13px;">Codigo: ${payload.qrAuthCode}</p>
      </div>

      <p style="margin:0 0 8px 0;color:#334155;">Presenta este QR en tienda para identificarte como cliente afiliado.</p>
      ${demoNota}
    `);

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: resendFrom,
        to: [targetEmail],
        subject: "Tu QR de cliente afiliado Osyra",
        html,
      }),
    });

    if (!resendResponse.ok) {
      const errorText = await resendResponse.text();
      return new Response(
        JSON.stringify({ error: "Fallo enviando email", details: errorText }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: "Error inesperado", details: String(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
