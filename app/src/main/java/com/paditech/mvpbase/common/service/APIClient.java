package com.paditech.mvpbase.common.service;

import android.util.Log;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.security.SecureRandom;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.util.Iterator;
import java.util.Map;
import java.util.SortedMap;
import java.util.concurrent.TimeUnit;

import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSession;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;

import okhttp3.Call;
import okhttp3.FormBody;
import okhttp3.MultipartBody;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okio.Buffer;

/**
 * japa_android
 * <p>
 * Created by Paditech on 6/27/2017.
 * Copyright (c) 2017 Paditech. All rights reserved.
 */

public class APIClient {

    private static final String TAG = APIClient.class.getSimpleName();

    private static final String BASE_URL = "http://japa.paditech.com/api/apidoc";

    private static APIClient instance;

    private static final OkHttpClient mHttpClient = generateDefaultOkHttp();

    private APIClient() {
        super();
    }

    public static APIClient getInstance() {
        if (instance == null) {
            instance = new APIClient();
        }
        return instance;
    }

    private static OkHttpClient generateDefaultOkHttp() {
        OkHttpClient.Builder okHttpClient = new OkHttpClient.Builder()
                .connectTimeout(60, TimeUnit.SECONDS)
                .readTimeout(60, TimeUnit.SECONDS)
                .writeTimeout(60, TimeUnit.SECONDS)
                .retryOnConnectionFailure(true);

        final TrustManager[] certs = new TrustManager[]{new X509TrustManager() {

            @Override
            public X509Certificate[] getAcceptedIssuers() {
                return null;
            }

            @Override
            public void checkServerTrusted(final X509Certificate[] chain,
                                           final String authType) throws CertificateException {
            }

            @Override
            public void checkClientTrusted(final X509Certificate[] chain,
                                           final String authType) throws CertificateException {
            }
        }};

        SSLContext ctx = null;
        try {
            ctx = SSLContext.getInstance("TLS");
            ctx.init(null, certs, new SecureRandom());
        } catch (final java.security.GeneralSecurityException ex) {
        }

        try {
            final HostnameVerifier hostnameVerifier = new HostnameVerifier() {
                @Override
                public boolean verify(final String hostname,
                                      final SSLSession session) {
                    return true;
                }
            };
            okHttpClient.hostnameVerifier(hostnameVerifier);
            okHttpClient.sslSocketFactory(ctx.getSocketFactory());
        } catch (final Exception e) {
        }

        OkHttpClient client = okHttpClient.build();
        return client;
    }

    static String getResourceURL(String resource) {
        return String.format("%s%s", BASE_URL, resource);
    }

    public static JSONObject extractData(JSONObject jsonObject) throws JSONException {
        return jsonObject.getJSONObject("");
    }

    static String makeQueryString(Map<String, String> params) {
        StringBuilder sb = new StringBuilder();

        for (Map.Entry<String, String> entry : params.entrySet()) {
            if (sb.length() > 0) {
                sb.append("&");
            }

            try {
                sb.append(URLEncoder.encode(entry.getKey(), "utf-8")).append("=")
                        .append(URLEncoder.encode(entry.getValue(), "utf-8"));
            } catch (UnsupportedEncodingException e) {
                Log.w(TAG, "Encode Error", e);
            }

        }

        if (sb.length() > 0) {
            sb.insert(0, "?");
            return sb.toString();
        } else {
            return "";
        }

    }

    private static String bodyToString(final Request request) {

        try {
            final Request copy = request.newBuilder().build();
            final Buffer buffer = new Buffer();
            copy.body().writeTo(buffer);
            return buffer.readUtf8();
        } catch (final IOException e) {
            return "did not work";
        }
    }

    private static String bodyToString(final RequestBody request) {
        try {
            final RequestBody copy = request;
            final Buffer buffer = new Buffer();
            copy.writeTo(buffer);
            return buffer.readUtf8();
        } catch (final IOException e) {
            return "did not work";
        }
    }

    private void execMethod(String url, String method, RequestBody body, ICallBack callback) {
        Log.i(TAG, String.format("method=%s, url=%s", method, url));
        final Request.Builder rb = new Request.Builder().url(url).method(method, body)
                .addHeader("Accept", "application/json")
                .addHeader("Accept", "text/html")
                .addHeader("Accept", "application/xhtml+xml")
                .addHeader("Accept", "application/xml;q=0.9,*/*;q=0.8 ")
                .tag(url);
        mHttpClient.newCall(rb.build()).enqueue(callback);
    }

    public void execGet(String uri, SortedMap<String, String> params, ICallBack callback) {
        StringBuilder sb = new StringBuilder();
        sb.append(getResourceURL(uri)).append(makeQueryString(params));
        final String url = sb.toString();
        execMethod(url, "GET", null, callback);
    }

    public void execDelete(String uri, SortedMap<String, String> params, ICallBack callback) {
        StringBuilder sb = new StringBuilder();
        sb.append(getResourceURL(uri)).append(makeQueryString(params));
        final String url = sb.toString();
        execMethod(url, "DELETE", null, callback);
    }

    public void execPost(String uri, SortedMap<String, String> params, ICallBack callback) {
        FormBody.Builder fb = new FormBody.Builder();
        for (Iterator<String> iterator = params.keySet().iterator(); iterator.hasNext(); ) {
            String key = iterator.next();
            String value = params.get(key);
            fb.add(key, value);
        }
        execMethod(getResourceURL(uri), "POST", fb.build(), callback);
    }

    public void execPostWithUrlParameters(String uri, SortedMap<String, String> urlParams, SortedMap<String, String> formParams, ICallBack callback) {
        StringBuilder sb = new StringBuilder();
        sb.append(getResourceURL(uri)).append(makeQueryString(urlParams));
        final String url = sb.toString();
        FormBody.Builder fb = new FormBody.Builder();
        for (Iterator<String> iterator = formParams.keySet().iterator(); iterator.hasNext(); ) {
            String key = iterator.next();
            String value = formParams.get(key);
            fb.add(key, value);
        }
        execMethod(url, "POST", fb.build(), callback);
    }

    public void execMultipartPost(String uri, SortedMap<String, String> params, SortedMap<String, RequestBody> files, ICallBack callback) {
        final MultipartBody.Builder mb = new MultipartBody.Builder()
                .setType(MultipartBody.FORM);
        for (Iterator<String> iterator = params.keySet().iterator(); iterator.hasNext(); ) {
            String key = iterator.next();
            mb.addFormDataPart(key, params.get(key));
        }

        for (Iterator<String> iterator = files.keySet().iterator(); iterator.hasNext(); ) {
            String key = iterator.next();
            mb.addFormDataPart(key, key, files.get(key));
        }
        execMethod(getResourceURL(uri), "POST", mb.build(), callback);
    }

    public void execPut(String uri, SortedMap<String, String> params, ICallBack callback) {
        FormBody.Builder fb = new FormBody.Builder();
        for (Iterator<String> iterator = params.keySet().iterator(); iterator.hasNext(); ) {
            String key = iterator.next();
            String value = params.get(key);
            fb.add(key, value);
        }
        execMethod(getResourceURL(uri), "PUT", fb.build(), callback);
    }

    public void execMultipartPut(String uri, SortedMap<String, String> params, SortedMap<String, RequestBody> files, ICallBack callback) {
        final MultipartBody.Builder mb = new MultipartBody.Builder()
                .setType(MultipartBody.FORM);
        for (Iterator<String> iterator = params.keySet().iterator(); iterator.hasNext(); ) {
            String key = iterator.next();
            mb.addFormDataPart(key, params.get(key));
        }

        for (Iterator<String> iterator = files.keySet().iterator(); iterator.hasNext(); ) {
            String key = iterator.next();
            mb.addFormDataPart(key, key, files.get(key));
        }
        execMethod(getResourceURL(uri), "PUT", mb.build(), callback);
    }

    public void downloadFile(String fileUrl, SortedMap<String, String> params, ICallBack callback) {
        StringBuilder sb = new StringBuilder();
        if (params != null) {
            sb.append(fileUrl).append(makeQueryString(params));
        }
        final String url = sb.toString();
        execMethod(url, "GET", null, callback);
    }

    public void cancelRequestWithTag(Object tag) {
        for (Call call : mHttpClient.dispatcher().queuedCalls()) {
            if (tag.equals(call.request().tag())) call.cancel();
        }
        for (Call call : mHttpClient.dispatcher().runningCalls()) {
            if (tag.equals(call.request().tag())) call.cancel();
        }
    }

    public void cancelAllRequests() {
        mHttpClient.dispatcher().cancelAll();
    }
}
