//
//  ShortsShimmerView.swift
//  JioNewsShortsSDK
//
//  Created by Bhavin Bhadani on 16/01/24.
//

import UIKit


internal class ShortsShimmerView: UIView {
    
    private var view1: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isSkeletonable = true
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()
    
    private var view2: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isSkeletonable = true
        view.layer.cornerRadius = 4
        view.clipsToBounds = true
        return view
    }()
    
    private var view3: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isSkeletonable = true
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()
    
    private var view4: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isSkeletonable = true
        view.layer.cornerRadius = 4
        view.clipsToBounds = true
        return view
    }()
    
    private var view5: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isSkeletonable = true
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()
    
    private var view6: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isSkeletonable = true
        view.layer.cornerRadius = 4
        view.clipsToBounds = true
        return view
    }()
    
    private var view7: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isSkeletonable = true
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()
    
    private var view8: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isSkeletonable = true
        view.layer.cornerRadius = 6
        view.clipsToBounds = true
        return view
    }()
    
    private var view9: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isSkeletonable = true
        view.layer.cornerRadius = 6
        view.clipsToBounds = true
        return view
    }()

    private var view10: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isSkeletonable = true
        view.layer.cornerRadius = 6
        view.clipsToBounds = true
        return view
    }()

    private var view11: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isSkeletonable = true
        view.layer.cornerRadius = 6
        view.clipsToBounds = true
        return view
    }()
    
    private var theme: JioShortsTheme = .light
    private let lightShimmerColor = UIColor(displayP3Red: 0.878, green: 0.878, blue: 0.878, alpha: 1)
    private let darkShimmerColor = UIColor(displayP3Red: 0.169, green: 0.169, blue: 0.169, alpha: 1)
    
    init(frame: CGRect, theme: JioShortsTheme = .light) {
        super.init(frame: frame)
        self.isSkeletonable = true
        self.theme = theme
        self.backgroundColor = (theme == .dark) ? UIColor.black : UIColor.white
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        self.addSubview(view1)
        self.addSubview(view2)
        self.addSubview(view3)
        self.addSubview(view4)
        self.addSubview(view5)
        self.addSubview(view6)
        self.addSubview(view7)
        self.addSubview(view8)
        self.addSubview(view9)
        self.addSubview(view10)
        self.addSubview(view11)
        
        let shimmerColor = (theme == .dark) ? darkShimmerColor : lightShimmerColor
        view1.backgroundColor = shimmerColor
        view2.backgroundColor = shimmerColor
        view3.backgroundColor = shimmerColor
        view4.backgroundColor = shimmerColor
        view5.backgroundColor = shimmerColor
        view6.backgroundColor = shimmerColor
        view7.backgroundColor = shimmerColor
        view8.backgroundColor = shimmerColor
        view9.backgroundColor = shimmerColor
        view10.backgroundColor = shimmerColor
        view11.backgroundColor = shimmerColor

        NSLayoutConstraint.activate([
            view1.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
            view1.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -16),
            view1.heightAnchor.constraint(equalToConstant: 24),
            view1.widthAnchor.constraint(equalToConstant: 24),
            view1.topAnchor.constraint(equalTo: view2.bottomAnchor, constant: 25),

            view2.heightAnchor.constraint(equalToConstant: 8),
            view2.widthAnchor.constraint(equalToConstant: 22),
            view2.topAnchor.constraint(equalTo: view3.bottomAnchor, constant: 8),
            view2.centerXAnchor.constraint(equalTo: view3.centerXAnchor),
            
            view3.trailingAnchor.constraint(equalTo: view1.trailingAnchor),
            view3.heightAnchor.constraint(equalToConstant: 24),
            view3.widthAnchor.constraint(equalToConstant: 24),
            view3.topAnchor.constraint(equalTo: view4.bottomAnchor, constant: 25),

            view4.heightAnchor.constraint(equalToConstant: 8),
            view4.widthAnchor.constraint(equalToConstant: 22),
            view4.topAnchor.constraint(equalTo: view5.bottomAnchor, constant: 8),
            view4.centerXAnchor.constraint(equalTo: view5.centerXAnchor),

            view5.trailingAnchor.constraint(equalTo: view3.trailingAnchor),
            view5.heightAnchor.constraint(equalToConstant: 24),
            view5.widthAnchor.constraint(equalToConstant: 24),
            view5.topAnchor.constraint(equalTo: view6.bottomAnchor, constant: 25),

            view6.heightAnchor.constraint(equalToConstant: 8),
            view6.widthAnchor.constraint(equalToConstant: 22),
            view6.topAnchor.constraint(equalTo: view7.bottomAnchor, constant: 8),
            view6.centerXAnchor.constraint(equalTo: view7.centerXAnchor),

            view7.trailingAnchor.constraint(equalTo: view5.trailingAnchor),
            view7.heightAnchor.constraint(equalToConstant: 24),
            view7.widthAnchor.constraint(equalToConstant: 24),
            
            view8.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            view8.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -16),
            view8.heightAnchor.constraint(equalToConstant: 12),
            view8.widthAnchor.constraint(equalToConstant: 120),
            view8.topAnchor.constraint(equalTo: view9.bottomAnchor, constant: 8),

            view9.leadingAnchor.constraint(equalTo: view8.leadingAnchor),
            view9.heightAnchor.constraint(equalToConstant: 12),
            view9.widthAnchor.constraint(equalToConstant: 236),
            view9.topAnchor.constraint(equalTo: view10.bottomAnchor, constant: 8),
            
            view10.leadingAnchor.constraint(equalTo: view9.leadingAnchor),
            view10.trailingAnchor.constraint(equalTo: view2.leadingAnchor, constant: -16),
            view10.heightAnchor.constraint(equalToConstant: 12),
            view10.topAnchor.constraint(equalTo: view11.bottomAnchor, constant: 8),

            view11.leadingAnchor.constraint(equalTo: view10.leadingAnchor),
            view11.trailingAnchor.constraint(equalTo: view10.trailingAnchor),
            view11.heightAnchor.constraint(equalToConstant: 12),
        ])
    }
    
    public func startShimmer() {
        let shimmerColor = (theme == .dark) ? darkShimmerColor : lightShimmerColor
        let gradient = SkeletonGradient(baseColor: shimmerColor, secondaryColor: shimmerColor.withAlphaComponent(0.5))
        showAnimatedGradientSkeleton(usingGradient: gradient, animation: nil, transition: .crossDissolve(0.25))
    }
    
    public func stopShimmer() {
        hideSkeleton()
    }

}
