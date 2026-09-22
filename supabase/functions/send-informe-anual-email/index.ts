import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type Payload = {
  anio: number;
  fechaInicio: string;
  fechaFin: string;
  totalTickets: number;
  totalVentas: number;
  filtro: string;
  generatedAt: string;
  pathProductos?: string;
  pathResumen?: string;
  productosFilename?: string;
  productosBase64?: string;
  resumenFilename?: string;
  resumenBase64?: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function htmlTemplate(payload: Payload): string {
  const totalFmt = Number(payload.totalVentas || 0).toFixed(2);

  return `
  <div style="font-family:Arial,Helvetica,sans-serif;background:#f3f6f7;padding:24px;">
    <div style="max-width:640px;margin:0 auto;background:#ffffff;border:1px solid #d9e3e6;border-radius:14px;padding:22px;">
      <h2 style="margin:0 0 10px 0;color:#0f172a;">Informe anual generado</h2>
      <p style="margin:0 0 14px 0;color:#334155;">Se ha generado un informe anual desde la app Osyra.</p>

      <div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;padding:12px;">
        <p style="margin:0 0 6px 0;color:#334155;"><strong>Ejercicio:</strong> ${payload.anio}</p>
        <p style="margin:0 0 6px 0;color:#334155;"><strong>Rango:</strong> ${payload.fechaInicio} - ${payload.fechaFin}</p>
        <p style="margin:0 0 6px 0;color:#334155;"><strong>Filtro:</strong> ${payload.filtro}</p>
        <p style="margin:0 0 6px 0;color:#334155;"><strong>Tickets exportados:</strong> ${payload.totalTickets}</p>
        <p style="margin:0;color:#334155;"><strong>Total ventas:</strong> ${totalFmt} EUR</p>
      </div>

      <p style="margin:14px 0 4px 0;color:#64748b;font-size:12px;">Generado en: ${payload.generatedAt}</p>
      ${payload.pathProductos ? `<p style="margin:2px 0;color:#64748b;font-size:12px;">Excel local: ${payload.pathProductos}</p>` : ""}
      ${payload.pathResumen ? `<p style="margin:2px 0;color:#64748b;font-size:12px;">PDF local: ${payload.pathResumen}</p>` : ""}
    </div>
  </div>`;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    const resendFrom = Deno.env.get("RESEND_FROM") ?? "Osyra <informes@osyra.local>";
    const reportTo = Deno.env.get("REPORTS_TO_EMAIL");
    const resendForceTo = Deno.env.get("RESEND_FORCE_TO_EMAIL")?.trim() ?? "";

    if (!resendApiKey) {
      throw new Error("Falta RESEND_API_KEY en variables de entorno.");
    }

    if (!reportTo) {
      throw new Error("Falta REPORTS_TO_EMAIL en variables de entorno.");
    }

    const payload = (await req.json()) as Payload;

    if (
      !payload.anio ||
      !payload.fechaInicio ||
      !payload.fechaFin ||
      payload.totalTickets == null ||
      payload.totalVentas == null ||
      !payload.filtro ||
      !payload.generatedAt
    ) {
      return new Response(
        JSON.stringify({ error: "Payload incompleto para correo de informe anual." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const html = htmlTemplate(payload);
    const targetEmail = resendForceTo.length > 0
      ? resendForceTo
      : reportTo;

    const attachments = [] as Array<{ filename: string; content: string }>;
    if (payload.productosFilename && payload.productosBase64) {
      attachments.push({
        filename: payload.productosFilename,
        content: payload.productosBase64,
      });
    }
    if (payload.resumenFilename && payload.resumenBase64) {
      attachments.push({
        filename: payload.resumenFilename,
        content: payload.resumenBase64,
      });
    }

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: resendFrom,
        to: [targetEmail],
        subject: `Informe anual Osyra ${payload.anio}`,
        html,
        attachments,
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
