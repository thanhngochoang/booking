package com.paditech.mvpbase.common.utils.get_location;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.IntentSender;
import android.content.pm.PackageManager;
import android.location.Location;
import android.net.Uri;
import android.os.Bundle;
import android.os.Looper;
import android.provider.Settings;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;
import android.util.Log;

import com.google.android.gms.common.api.ResolvableApiException;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationCallback;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationResult;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.LocationSettingsRequest;
import com.google.android.gms.location.SettingsClient;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.base.BaseDialog;
import com.paditech.mvpbase.common.mvp.activity.MVPActivity;
import com.paditech.mvpbase.common.mvp.fragment.MVPFragment;

/**
 * Created by ThanhNgocHoang on 9/18/2017.
 */

public class GetLocationManager {
    private final static String TAG = GetLocationManager.class.getSimpleName();
    private final static int PERMISSION_LOCATION = 101;
    private final static int SETTINGS_LOCATION = 201;
    private final int REQUEST_CHECK_SETTINGS = 301;

    private MVPActivity mActivity;
    private MVPFragment mFragment;
    private FusedLocationProviderClient mFusedLocationClient;
    private LocationRequest mLocationRequest;
    private LocationCallback mLocationCallback;
    private OnCurrentLocationListener mOnCurrentLocationListener;

    public GetLocationManager(MVPActivity mActivity) {
        this.mActivity = mActivity;
        init();
    }

    public GetLocationManager(MVPFragment mFragment) {
        this.mFragment = mFragment;
        init();
    }

    public void setmOnCurrentLocationListener(OnCurrentLocationListener mOnCurrentLocationListener) {
        this.mOnCurrentLocationListener = mOnCurrentLocationListener;
    }

    private MVPActivity getActivity() {
        if (mActivity != null) return mActivity;
        if (mFragment != null) return (MVPActivity) mFragment.getActivity();
        return null;
    }

    private Context getContext() {
        if (mActivity != null) return mActivity;
        if (mFragment != null) return mFragment.getContext();
        return null;
    }

    private void init() {
        mLocationRequest = LocationRequest.create()
                .setPriority(LocationRequest.PRIORITY_HIGH_ACCURACY)
                .setInterval(10000)        // 10 seconds, in milliseconds
                .setFastestInterval(1000); // 1 second, in milliseconds

        if (getContext() != null)
            mFusedLocationClient = LocationServices.getFusedLocationProviderClient(getContext());

    }

    public void getCurrentLocation() {
        try {
            if (!checkPermissionValid()) return;
            mLocationCallback = new LocationCallback() {
                @Override
                public void onLocationResult(LocationResult locationResult) {
                    super.onLocationResult(locationResult);
                    Location location = locationResult.getLastLocation();
                    if (location != null && mOnCurrentLocationListener != null)
                        mOnCurrentLocationListener.onCurrentLocationResult(location);
                }
            };
            if (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.ACCESS_FINE_LOCATION)
                    != PackageManager.PERMISSION_GRANTED
                    && ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.ACCESS_COARSE_LOCATION)
                    != PackageManager.PERMISSION_GRANTED) {
                return;
            }
            mFusedLocationClient.requestLocationUpdates(mLocationRequest, mLocationCallback, Looper.getMainLooper());
            mFusedLocationClient.getLastLocation().addOnCompleteListener(new OnCompleteListener<Location>() {
                @Override
                public void onComplete(@NonNull Task<Location> task) {
                    if (task.isSuccessful()) {
                        Location location = task.getResult();
                        if (location != null) {
                            if (mOnCurrentLocationListener != null)
                                mOnCurrentLocationListener.onCurrentLocationResult(location);
                        } else {
                            checkLocationEnable();
                        }
                    } else checkLocationEnable();
                }
            });
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private boolean checkPermissionValid() {
        if (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED
                && ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            if (!ActivityCompat.shouldShowRequestPermissionRationale(getActivity(),
                    Manifest.permission.ACCESS_FINE_LOCATION)) {
                ActivityCompat.requestPermissions(getActivity(),
                        new String[]{Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION},
                        PERMISSION_LOCATION);
            } else {
                getActivity().showConfirmDialog(false, getContext().getString(R.string.mess_permission_location)
                        , getContext().getString(R.string.ok), getContext().getString(R.string.cancel)
                        , new BaseDialog.OnPositiveClickListener() {
                            @Override
                            public void onPositiveClick() {
                                Intent intent = new Intent();
                                intent.setAction(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                                Uri uri = Uri.fromParts("package", getContext().getPackageName(), null);
                                intent.setData(uri);
                                if (mActivity != null)
                                    mActivity.startActivityForResult(intent, SETTINGS_LOCATION);
                                if (mFragment != null)
                                    mFragment.startActivityForResult(intent, SETTINGS_LOCATION);
                            }
                        }, new BaseDialog.OnNegativeClickListener() {
                            @Override
                            public void onNegativeClick() {

                            }
                        });
            }
            return false;
        } else return true;
    }

    private void checkLocationEnable() {
        LocationSettingsRequest.Builder builder = new LocationSettingsRequest.Builder().addLocationRequest(mLocationRequest);
        builder.setAlwaysShow(true);
        SettingsClient client = LocationServices.getSettingsClient(getContext());
        client.checkLocationSettings(builder.build())
                .addOnSuccessListener(response -> Log.i(TAG, "All location settings are satisfied."))
                .addOnFailureListener(e -> {
                    if (e instanceof ResolvableApiException) {
                        Log.i(TAG, "Location settings are not satisfied. Show the user a dialog to upgrade location settings");
                        try {
                            ((ResolvableApiException) e).startResolutionForResult(getActivity(), REQUEST_CHECK_SETTINGS);
                        } catch (IntentSender.SendIntentException ex) {
                            Log.i(TAG, "PendingIntent unable to execute request.");
                        }
                    } else {
                        Log.i(TAG, "Location settings are inadequate, and cannot be fixed here. Dialog not created.");
                    }
                });
    }

    public void onDestroy() {
        if (mFusedLocationClient != null && mLocationCallback != null)
            mFusedLocationClient.removeLocationUpdates(mLocationCallback);
    }

    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        if (requestCode == PERMISSION_LOCATION) {
            getCurrentLocation();
        }
    }

    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (resultCode == Activity.RESULT_OK && requestCode == REQUEST_CHECK_SETTINGS) {
            if (ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
                    ActivityCompat.checkSelfPermission(getContext(), Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                return;
            }
            getCurrentLocation();
        }
    }

    public interface OnCurrentLocationListener {
        void onCurrentLocationResult(Location location);
    }

}
