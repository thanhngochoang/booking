package com.paditech.mvpbase.common.view;

import android.content.Context;
import android.content.Intent;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.util.AttributeSet;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.utils.ImageUtil;
import com.paditech.mvpbase.screen.view_image.ViewImageActivity;

import java.util.ArrayList;

import butterknife.BindView;
import butterknife.ButterKnife;
import butterknife.OnClick;

/**
 * Created by ThanhNgocHoang on 11/26/2017.
 */

public class AutoTopImageLayout extends FrameLayout {
    @BindView(R.id.image_1)
    ImageView image1;
    @BindView(R.id.image_3)
    ImageView image3;
    @BindView(R.id.image_4)
    ImageView image4;
    @BindView(R.id.image_2)
    ImageView image2;
    @BindView(R.id.layout_34)
    View layout34;
    @BindView(R.id.layout_234)
    View layout234;
    private LinearLayout mainLayout;

    private ArrayList<String> mListImages;

    public AutoTopImageLayout(@NonNull Context context) {
        super(context);
        initView();
    }

    public AutoTopImageLayout(@NonNull Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        initView();
    }

    public AutoTopImageLayout(@NonNull Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        initView();
    }

    private void initView() {
        mainLayout = (LinearLayout) LayoutInflater.from(getContext()).inflate(R.layout.view_auto_top_image, this, false);
        ButterKnife.bind(this, mainLayout);
        try {
            if (mainLayout.getParent() != null) {
                ((ViewGroup) mainLayout.getParent()).removeView(mainLayout);
            }
            addView(mainLayout);
        } catch (Exception e){
            e.printStackTrace();
        }


    }

    @OnClick({R.id.image_1, R.id.image_3, R.id.image_4, R.id.image_2})
    public void onViewClicked(View view) {
        String image = null;
        switch (view.getId()) {
            case R.id.image_1:
                image = mListImages.get(0);
                break;
            case R.id.image_3:
                image = mListImages.get(2);
                break;
            case R.id.image_4:
                image = mListImages.get(3);
                break;
            case R.id.image_2:
                image = mListImages.get(1);
                break;
        }
        if (image == null) return;
        Intent intent = new Intent(getContext(), ViewImageActivity.class);
        intent.putExtra("image_url", image);
        getContext().startActivity(intent);

    }

    public void setmListImages(ArrayList<String> mListImages) {
        this.mListImages = mListImages;
        updateView();
    }

    private void updateView() {
        try {
            mainLayout.setWeightSum(5);
            switch (mListImages.size()) {
                case 1:
                    image1.setVisibility(VISIBLE);
                    image2.setVisibility(GONE);
                    image3.setVisibility(GONE);
                    image4.setVisibility(GONE);
                    mainLayout.setWeightSum(3);
                    ImageUtil.loadImage(getContext(), mListImages.get(0), image1, R.color.white_transfer, R.color.white_transfer);
                    layout234.setVisibility(GONE);
                    break;
                case 2:
                    image1.setVisibility(VISIBLE);
                    image2.setVisibility(VISIBLE);
                    image3.setVisibility(GONE);
                    image4.setVisibility(GONE);
                    layout234.setVisibility(VISIBLE);
                    layout34.setVisibility(GONE);
                    ImageUtil.loadImage(getContext(), mListImages.get(0), image1, R.color.white_transfer, R.color.white_transfer);
                    ImageUtil.loadImage(getContext(), mListImages.get(1), image2, R.color.white_transfer, R.color.white_transfer);
                    break;
                case 3:
                    image1.setVisibility(VISIBLE);
                    image2.setVisibility(VISIBLE);
                    image3.setVisibility(VISIBLE);
                    image4.setVisibility(GONE);
                    layout34.setVisibility(VISIBLE);
                    layout234.setVisibility(VISIBLE);
                    ImageUtil.loadImage(getContext(), mListImages.get(0), image1, R.color.white_transfer, R.color.white_transfer);
                    ImageUtil.loadImage(getContext(), mListImages.get(1), image2, R.color.white_transfer, R.color.white_transfer);
                    ImageUtil.loadImage(getContext(), mListImages.get(2), image3, R.color.white_transfer, R.color.white_transfer);
                    break;
                case 4:
                    image1.setVisibility(VISIBLE);
                    image2.setVisibility(VISIBLE);
                    image3.setVisibility(VISIBLE);
                    image4.setVisibility(VISIBLE);
                    layout34.setVisibility(VISIBLE);
                    layout234.setVisibility(VISIBLE);
                    ImageUtil.loadImage(getContext(), mListImages.get(0), image1, R.color.white_transfer, R.color.white_transfer);
                    ImageUtil.loadImage(getContext(), mListImages.get(1), image2, R.color.white_transfer, R.color.white_transfer);
                    ImageUtil.loadImage(getContext(), mListImages.get(2), image3, R.color.white_transfer, R.color.white_transfer);
                    ImageUtil.loadImage(getContext(), mListImages.get(3), image4, R.color.white_transfer, R.color.white_transfer);
                    break;
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
